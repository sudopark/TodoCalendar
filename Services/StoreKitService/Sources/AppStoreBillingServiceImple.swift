//
//  AppStoreBillingServiceImple.swift
//  StoreKitService
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import StoreKit
import Domain
import Extensions


// StoreKit 을 아는 유일한 프레임워크(StoreKitService)의 유일한 구현. Repository 에 의존하지 않는다 —
// Domain 프로토콜 시그니처에 StoreKit 타입이 없어 이동이 파일 위치 변경으로 끝났다
public final class AppStoreBillingServiceImple: AppStoreBillingService, Sendable {

    // transactionUpdates 를 접근할 때마다 새로 만들면 소비자가 둘 이상일 때 같은 트랜잭션이
    // 이중 post 된다 — init 에서 1회만 만들어 저장. 리스너 Task 도 init 시점에 뜨므로
    // 트랜잭션이 드문 특성상 버퍼링 부담 없이 startObservingTransactions 이전 도착분도 받는다
    public let transactionUpdates: AsyncStream<BillingSignedTransaction>

    // Task 를 continuation 의 onTermination 클로저에 맡기면 순환이 닫힌다 —
    // Transaction.updates 는 끝나지 않아 소비자가 스트림을 취소하기 전엔 안 풀린다.
    // 서비스가 직접 소유해 deinit 에서 끊는다
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

        // 승인대기(Ask to Buy)는 나중에 Transaction.updates 로 도착한다
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


// MARK: - restore / recovery / updates

extension AppStoreBillingServiceImple {

    // 소모품(top-up)은 currentEntitlements 에 잡히지 않는다 —
    // 애플이 보유 상태를 들고 있지 않아서다. 잔량 원장의 진실은 서버뿐이다
    public func restorePurchases() async throws -> [BillingSignedTransaction] {
        try await AppStore.sync()
        return await self.collect(StoreKit.Transaction.currentEntitlements)
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
