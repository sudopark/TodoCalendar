//
//  AppStoreBillingServiceImple.swift
//  StoreKitService
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import StoreKit
import Prelude
import Optics
import Domain
import Extensions


public final class AppStoreBillingServiceImple: AppStoreBillingService, Sendable {

    public let transactionUpdates: AsyncStream<BillingSignedTransaction>

    private let listenerTask: Task<Void, Never>

    public init() {
        let (stream, continuation) = AsyncStream<BillingSignedTransaction>.makeStream()
        self.transactionUpdates = stream
        self.listenerTask = Task {
            for await result in StoreKit.Transaction.updates {
                guard let transaction = try? verifiedTransaction(result) else { continue }
                continuation.yield(transaction)
            }
            continuation.finish()
        }
    }

    deinit {
        self.listenerTask.cancel()
    }
}


// MARK: - product

extension AppStoreBillingServiceImple {

    public func loadProducts(ids: [String]) async throws -> [BillingProduct] {
        let products = try await Product.products(for: ids)
        return products.map {
            BillingProduct(
                productId: $0.id,
                displayName: $0.displayName,
                displayPrice: $0.displayPrice
            )
            |> \.kind .~ productKind($0)
        }
    }
}


// MARK: - purchase

extension AppStoreBillingServiceImple {

    public func purchase(productId: String) async throws -> BillingTransactionOutcome {
        guard let product = try await Product.products(for: [productId]).first
        else { throw RuntimeError("unknown app store product: \(productId)") }

        switch try await product.purchase() {
        case .success(let result):
            return .verified(try verifiedTransaction(result))

        case .userCancelled:
            return .cancelled

        case .pending:
            return .pending

        // 모르는 결과를 성공으로 취급하지 않는다
        @unknown default:
            return .cancelled
        }
    }

}


// MARK: - verification

// 타입 멤버가 아닌 파일 스코프 함수 — init 의 AsyncStream 빌더 클로저는 self 가 아직
// 초기화되지 않아 인스턴스 메서드를 부를 수 없다. 상태를 안 쓰는 순수 변환이라 밖으로 뺀다.
// .unverified 는 서명이 깨진 것 — 절대 서버로 올리지 않는다
private func verifiedTransaction(
    _ result: VerificationResult<StoreKit.Transaction>
) throws -> BillingSignedTransaction {
    switch result {
    case .verified(let transaction):
        return BillingSignedTransaction(
            id: "\(transaction.id)",
            productId: transaction.productID,
            jws: result.jwsRepresentation
        )
    case .unverified:
        throw RuntimeError("unverified app store transaction")
    }
}

private func productKind(_ product: StoreKit.Product) -> BillingProductKind {
    guard product.type == .autoRenewable, let subscription = product.subscription
    else { return .oneTime }
    return .subscription(period: subscriptionPeriod(subscription.subscriptionPeriod))
}

private func subscriptionPeriod(_ period: StoreKit.Product.SubscriptionPeriod) -> BillingSubscriptionPeriod? {
    switch (period.unit, period.value) {
    case (.week, 1):  return .weekly
    case (.month, 1): return .monthly
    case (.year, 1):  return .yearly
    default:          return nil
    }
}


// MARK: - restore / recovery / updates

extension AppStoreBillingServiceImple {

    public func restorePurchases() async throws -> BillingRestoreOutcome {
        do {
            try await AppStore.sync()
        // 시스템 로그인 시트를 닫으면 sync() 가 이걸 던진다 — 실패가 아니다
        } catch StoreKitError.userCancelled {
            return .cancelled
        }
        return .synced(await self.collect(StoreKit.Transaction.currentEntitlements))
    }

    public func unfinishedTransactions() async -> [BillingSignedTransaction] {
        return await self.collect(StoreKit.Transaction.unfinished)
    }

    public func finishTransaction(id: String) async {
        for await result in StoreKit.Transaction.unfinished {
            guard case .verified(let transaction) = result, "\(transaction.id)" == id
            else { continue }
            await transaction.finish()
            return
        }
    }

    private func collect(
        _ sequence: StoreKit.Transaction.Transactions
    ) async -> [BillingSignedTransaction] {
        var transactions: [BillingSignedTransaction] = []
        for await result in sequence {
            guard let transaction = try? verifiedTransaction(result) else { continue }
            transactions.append(transaction)
        }
        return transactions
    }
}
