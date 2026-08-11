//
//  BillingUsecase.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


public protocol BillingUsecase: AnyObject, Sendable {

    func loadPlanOfferings() async throws -> [BillingPlanOffering]
    func loadTopupOfferings() async throws -> [BillingTopupOffering]

    // 유저 취소·승인대기(Ask to Buy) 는 에러가 아니다 — 결과를 구분해 반환
    func purchase(productId: String) async throws -> BillingPurchaseResult
    func restorePurchases() async throws -> BillingUserPlan?

    // paywall 진입 등에서 현재 플랜을 재확인한다. 성공하면 sharedDataStore 에 반영돼
    // currentUserPlan 구독자에게 흐른다. 실패는 호출측이 처리 (throws)
    @discardableResult
    func refreshUserPlan() async throws -> BillingUserPlan

    func startObservingTransactions()

    func stopObservingTransactions()

    func recoverUnfinishedTransactions()

    func hasUnfinishedTransactions() async -> Bool

    func applyUnfinishedTransactions() async throws -> BillingUserPlan?

    var currentUserPlan: AnyPublisher<BillingUserPlan, Never> { get }
}


public final class BillingUsecaseImple: BillingUsecase, @unchecked Sendable {

    private let repository: any BillingRepository
    private let appStoreService: any AppStoreBillingService
    private let sharedDataStore: SharedDataStore

    public init(
        repository: any BillingRepository,
        appStoreService: any AppStoreBillingService,
        sharedDataStore: SharedDataStore
    ) {
        self.repository = repository
        self.appStoreService = appStoreService
        self.sharedDataStore = sharedDataStore
    }

    private var observingTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?

    deinit {
        self.observingTask?.cancel()
        self.recoveryTask?.cancel()
    }
}


// MARK: - catalog

extension BillingUsecaseImple {

    public func loadPlanOfferings() async throws -> [BillingPlanOffering] {
        let plans = try await self.repository.loadPlans()
        let products = await self.products(for: plans.compactMap { $0.productId })
        return plans.map { plan in
            BillingPlanOffering(plan: plan)
                |> \.product .~ plan.productId.flatMap { products[$0] }
        }
    }

    public func loadTopupOfferings() async throws -> [BillingTopupOffering] {
        let topups = try await self.repository.loadTopups()
        let products = await self.products(for: topups.map { $0.productId })
        return topups.map { topup in
            BillingTopupOffering(topup: topup)
                |> \.product .~ products[topup.productId]
        }
    }

    // 스토어 조회 실패로 카탈로그 전체를 잃지 않는다 — 가격만 비는 편이 낫다
    private func products(for ids: [String]) async -> [String: BillingProduct] {
        guard !ids.isEmpty else { return [:] }
        let products = (try? await self.appStoreService.loadProducts(ids: ids)) ?? []
        return products.reduce(into: [:]) { $0[$1.productId] = $1 }
    }
}


// MARK: - purchase

extension BillingUsecaseImple {

    public func purchase(productId: String) async throws -> BillingPurchaseResult {
        switch try await self.appStoreService.purchase(productId: productId) {
        case .verified(let transaction):
            return .applied(try await self.applyAndFinish(transaction))
        case .cancelled:
            return .cancelled
        case .pending:
            return .pending
        }
    }

    public func restorePurchases() async throws -> BillingUserPlan? {
        let transactions = try await self.appStoreService.restorePurchases()
        return try await self.applyEach(transactions)
    }

    // finish 는 서버 반영이 성공한 뒤에만. 먼저 부르면 실패 시 영수증이 사라져 복구 불가다
    private func applyAndFinish(
        _ transaction: BillingSignedTransaction
    ) async throws -> BillingUserPlan {
        // 서버가 믿는 건 서명 payload 안의 값 — 앱이 판단한 productId 는 올리지 않는다
        let userPlan = try await self.wrappingReflectFailure {
            try await self.repository.postPurchase(signedTransaction: transaction.jws)
        }
        await self.appStoreService.finishTransaction(id: transaction.id)
        self.updateSharedUserPlan(userPlan)
        return userPlan
    }

    private func delegateAndFinish(
        _ transaction: BillingSignedTransaction
    ) async throws -> BillingUserPlan {
        let userPlan = try await self.wrappingReflectFailure {
            try await self.repository.postTransactionUpdate(signedTransaction: transaction.jws)
        }
        await self.appStoreService.finishTransaction(id: transaction.id)
        guard !Task.isCancelled else { return userPlan }
        self.updateSharedUserPlan(userPlan)
        return userPlan
    }

    private func wrappingReflectFailure(
        _ post: () async throws -> BillingUserPlan
    ) async throws -> BillingUserPlan {
        do {
            return try await post()
        } catch {
            throw BillingReflectFailure(error)
        }
    }

    private func updateSharedUserPlan(_ userPlan: BillingUserPlan) {
        self.sharedDataStore.put(
            BillingUserPlan.self,
            key: ShareDataKeys.billingUserPlan.rawValue,
            userPlan
        )
    }

    // 한 건이 영구 실패해도 나머지는 반영돼야 한다 — fail-fast 면 앞의 실패가 매 시도마다
    // 뒤 트랜잭션을 가려 영영 반영되지 않는다. 실패 사실은 첫 사유로 호출측에 던진다
    private func applyEach(
        _ transactions: [BillingSignedTransaction]
    ) async throws -> BillingUserPlan? {
        var latest: BillingUserPlan?
        var firstFailure: (any Error)?
        for transaction in transactions {
            guard !Task.isCancelled else { break }
            do {
                latest = try await self.delegateAndFinish(transaction)
            } catch {
                firstFailure = firstFailure ?? error
                logger.log(
                    level: .error, "billing transaction apply failed: \(error)",
                    with: ["transactionId": transaction.id]
                )
            }
        }
        if let firstFailure { throw firstFailure }
        return latest
    }
}


// MARK: - user plan query

extension BillingUsecaseImple {

    @discardableResult
    public func refreshUserPlan() async throws -> BillingUserPlan {
        let userPlan = try await self.repository.loadUserPlan()
        self.updateSharedUserPlan(userPlan)
        return userPlan
    }
}


// MARK: - transaction observing

extension BillingUsecaseImple {

    public func startObservingTransactions() {
        guard self.observingTask == nil else { return }
        // 앱 밖 갱신·환불·가족공유·승인대기 통과가 들어오는 유일한 경로
        let updates = self.appStoreService.transactionUpdates
        self.observingTask = Task { [weak self] in
            for await transaction in updates {
                guard let self else { return }
                do {
                    _ = try await self.delegateAndFinish(transaction)
                } catch {
                    logger.log(
                        level: .error, "billing transaction delegate failed (stream): \(error)",
                        with: ["transactionId": transaction.id]
                    )
                }
            }
        }
    }

    public func stopObservingTransactions() {
        self.observingTask?.cancel()
        self.observingTask = nil
        self.recoveryTask?.cancel()
        self.recoveryTask = nil
    }

    // unfinished 는 OS 전역이라 두 시도가 겹치면 같은 트랜잭션을 중복 전송한다
    public func recoverUnfinishedTransactions() {
        self.recoveryTask?.cancel()
        self.recoveryTask = Task { [weak self] in
            guard let self else { return }
            let transactions = await self.appStoreService.unfinishedTransactions()
            _ = try? await self.applyEach(transactions)
        }
    }

    public func hasUnfinishedTransactions() async -> Bool {
        return await self.appStoreService.unfinishedTransactions().isEmpty == false
    }

    public func applyUnfinishedTransactions() async throws -> BillingUserPlan? {
        let transactions = await self.appStoreService.unfinishedTransactions()
        return try await self.applyEach(transactions)
    }

    public var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
        return self.sharedDataStore.observe(
            BillingUserPlan.self,
            key: ShareDataKeys.billingUserPlan.rawValue
        )
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
