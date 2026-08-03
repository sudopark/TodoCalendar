//
//  StubBillingUsecase.swift
//  BillingScenesTests
//
//  Created by sudo.park on 8/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class StubBillingUsecase: BillingUsecase, @unchecked Sendable {

    private let stubOfferings: [BillingPlanOffering]
    // 서버 카탈로그 요청(loadPlans) 실패를 시뮬레이션 — nil이면 stubOfferings를 그대로 반환
    private let catalogLoadError: (any Error)?
    private let stubPurchaseResult: Result<BillingPurchaseResult, any Error>
    private let userPlanSubject: CurrentValueSubject<BillingUserPlan?, Never>

    // 호출 기록 — 검증은 테스트 케이스가 한다
    var didPurchasedProductId: String?
    var didRestoreCalled: Bool = false

    init(
        offerings: [BillingPlanOffering] = [],
        catalogLoadError: (any Error)? = nil,
        purchaseResult: Result<BillingPurchaseResult, any Error> = .success(.cancelled),
        userPlan: BillingUserPlan? = nil
    ) {
        self.stubOfferings = offerings
        self.catalogLoadError = catalogLoadError
        self.stubPurchaseResult = purchaseResult
        self.userPlanSubject = .init(userPlan)
    }

    func loadPlanOfferings() async throws -> [BillingPlanOffering] {
        if let catalogLoadError { throw catalogLoadError }
        return self.stubOfferings
    }
    func loadTopupOfferings() async throws -> [BillingTopupOffering] { [] }

    func purchase(productId: String) async throws -> BillingPurchaseResult {
        self.didPurchasedProductId = productId
        return try self.stubPurchaseResult.get()
    }

    func restorePurchases() async throws -> BillingUserPlan? {
        self.didRestoreCalled = true
        return self.userPlanSubject.value
    }

    func startObservingTransactions() { }

    var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
        self.userPlanSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
}
