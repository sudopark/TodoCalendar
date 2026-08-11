//
//  StubAppStoreBillingService.swift
//  DomainTests
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions

@testable import Domain


final class StubAppStoreBillingService: AppStoreBillingService, @unchecked Sendable {

    private let shouldCancelPurchase: Bool
    private let shouldCancelRestore: Bool
    private let shouldPurchaseBePending: Bool
    private let shouldFailPurchase: Bool
    private let shouldFailLoadProducts: Bool
    private let stubUnfinished: [BillingSignedTransaction]
    private let stubRestored: [BillingSignedTransaction]
    private let updatesStream: AsyncStream<BillingSignedTransaction>
    private let updatesContinuation: AsyncStream<BillingSignedTransaction>.Continuation

    init(
        shouldCancelPurchase: Bool = false,
        shouldCancelRestore: Bool = false,
        shouldPurchaseBePending: Bool = false,
        shouldFailPurchase: Bool = false,
        shouldFailLoadProducts: Bool = false,
        unfinished: [BillingSignedTransaction] = [],
        restored: [BillingSignedTransaction]? = nil
    ) {
        self.shouldCancelPurchase = shouldCancelPurchase
        self.shouldCancelRestore = shouldCancelRestore
        self.shouldPurchaseBePending = shouldPurchaseBePending
        self.shouldFailPurchase = shouldFailPurchase
        self.shouldFailLoadProducts = shouldFailLoadProducts
        self.stubUnfinished = unfinished
        self.stubRestored = restored ?? [
            BillingSignedTransaction(id: "tx:restored", productId: "plan.lifetime", jws: "jws:restored")
        ]

        var continuation: AsyncStream<BillingSignedTransaction>.Continuation!
        self.updatesStream = AsyncStream { continuation = $0 }
        self.updatesContinuation = continuation
    }

    // 기록만 한다 — 검증은 테스트 케이스 책임
    private(set) var didFinishedTransactionIds: [String] = []

    // 테스트가 앱 밖 트랜잭션 도착을 흉내낼 때 쓴다
    func sendTransactionUpdate(_ transaction: BillingSignedTransaction) {
        self.updatesContinuation.yield(transaction)
    }

    func loadProducts(ids: [String]) async throws -> [BillingProduct] {
        guard !self.shouldFailLoadProducts
        else { throw RuntimeError("store unreachable") }
        return ids.map {
            BillingProduct(productId: $0, displayName: "name:\($0)", displayPrice: "$0.49")
        }
    }

    func purchase(productId: String) async throws -> BillingTransactionOutcome {
        if self.shouldFailPurchase { throw RuntimeError("store purchase failed") }
        if self.shouldCancelPurchase { return .cancelled }
        if self.shouldPurchaseBePending { return .pending }
        return .verified(
            BillingSignedTransaction(
                id: "tx:\(productId)", productId: productId, jws: "jws:\(productId)"
            )
        )
    }

    func restorePurchases() async throws -> BillingRestoreOutcome {
        guard !self.shouldCancelRestore else { return .cancelled }
        return .synced(self.stubRestored)
    }

    func unfinishedTransactions() async -> [BillingSignedTransaction] {
        return self.stubUnfinished
    }

    var transactionUpdates: AsyncStream<BillingSignedTransaction> {
        return self.updatesStream
    }

    func finishTransaction(id: String) async {
        self.didFinishedTransactionIds.append(id)
    }
}
