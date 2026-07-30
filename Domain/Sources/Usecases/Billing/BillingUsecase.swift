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


public protocol BillingUsecase: AnyObject, Sendable {

    func loadPlanOfferings() async throws -> [BillingPlanOffering]
    func loadTopupOfferings() async throws -> [BillingTopupOffering]

    // 유저 취소·승인대기(Ask to Buy) 는 에러가 아니다 — 결과를 구분해 반환
    func purchase(productId: String) async throws -> BillingPurchaseResult
    func restorePurchases() async throws -> BillingUserPlan?

    // 앱 기동(로그인) 시 1회. 이후 생명주기 내내 유지된다.
    // 중복 호출 방어가 락 없는 플래그라 메인에서만 부른다
    func startObservingTransactions()

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

    deinit {
        self.observingTask?.cancel()
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
        let userPlan = try await self.repository.postPurchase(signedTransaction: transaction.jws)
        await self.appStoreService.finishTransaction(id: transaction.id)
        self.sharedDataStore.put(
            BillingUserPlan.self,
            key: ShareDataKeys.billingUserPlan.rawValue,
            userPlan
        )
        return userPlan
    }

    // 서버가 transactionId ledger 로 멱등이라 전건 재제출이 안전하다.
    // 순차 await 이라 for 루프가 필요하다 — 마지막 반영 결과가 최신 상태.
    // recoverUnfinishedTransactions 와 달리 여기는 fail-fast 가 의도다 — restorePurchases 는
    // 유저가 직접 누른 액션이라 실패가 화면에 그대로 노출되고 재시도도 유저가 다시 누르면 되므로,
    // 앞 건 실패를 숨기고 뒤 건만 반영하는 게 오히려 혼란스럽다
    private func applyEach(
        _ transactions: [BillingSignedTransaction]
    ) async throws -> BillingUserPlan? {
        var latest: BillingUserPlan?
        for transaction in transactions {
            latest = try await self.applyAndFinish(transaction)
        }
        return latest
    }
}


// MARK: - transaction observing

extension BillingUsecaseImple {

    public func startObservingTransactions() {
        guard self.observingTask == nil else { return }
        // 앱 밖 갱신·환불·가족공유·승인대기 통과가 들어오는 유일한 경로
        let updates = self.appStoreService.transactionUpdates
        self.observingTask = Task { [weak self] in
            // 서버 반영 전에 앱이 죽은 트랜잭션을 먼저 복구한 뒤 스트림을 연다
            await self?.recoverUnfinishedTransactions()
            // 루프 본문에서만 self 를 잡는다 — 끝나지 않는 스트림을 strong self 로 돌면
            // deinit 이 영영 오지 않아 아래 cancel 이 죽은 코드가 된다
            for await transaction in updates {
                guard let self else { return }
                _ = try? await self.applyAndFinish(transaction)
            }
        }
    }

    // 한 건이 영구 실패해도 나머지는 반영돼야 한다 — fail-fast 면 앞의 실패가
    // 매 기동마다 뒤 트랜잭션을 가려 영영 반영되지 않는다
    private func recoverUnfinishedTransactions() async {
        let transactions = await self.appStoreService.unfinishedTransactions()
        for transaction in transactions {
            _ = try? await self.applyAndFinish(transaction)
        }
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
