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
    // restorePurchases() 가 반환할 값. nil 이면 "복원할 구매 없음"
    private let restoreResult: BillingUserPlan?
    // refreshUserPlan() 실패를 시뮬레이션 — nil이면 성공 (#739)
    private let userPlanLoadError: (any Error)?
    private let userPlanSubject: CurrentValueSubject<BillingUserPlan?, Never>
    private let hasUnfinished: Bool
    private let applyUnfinishedResult: Result<BillingUserPlan?, any Error>

    // 호출 기록 — 검증은 테스트 케이스가 한다
    var didPurchasedProductId: String?
    var didRestoreCalled: Bool = false
    var didRefreshUserPlanCalled: Bool = false
    var didCheckUnfinishedCalled: Bool = false
    var didApplyUnfinishedTimes: Int = 0

    init(
        offerings: [BillingPlanOffering] = [],
        catalogLoadError: (any Error)? = nil,
        purchaseResult: Result<BillingPurchaseResult, any Error> = .success(.cancelled),
        userPlan: BillingUserPlan? = nil,
        restoreResult: BillingUserPlan? = nil,
        userPlanLoadError: (any Error)? = nil,
        hasUnfinished: Bool = false,
        applyUnfinishedResult: Result<BillingUserPlan?, any Error> = .success(nil)
    ) {
        self.stubOfferings = offerings
        self.catalogLoadError = catalogLoadError
        self.stubPurchaseResult = purchaseResult
        self.restoreResult = restoreResult
        self.userPlanLoadError = userPlanLoadError
        self.userPlanSubject = .init(userPlan)
        self.hasUnfinished = hasUnfinished
        self.applyUnfinishedResult = applyUnfinishedResult
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

    // 실제 usecase(BillingUsecaseImple.applyAndFinish)는 복원 결과를 sharedDataStore 에 반영해
    // currentUserPlan 이 자동으로 재방출된다 — 스텁도 값을 반환만 하지 않고 subject 에 push 해야
    // "선택 후 복원으로 보유 플랜이 바뀌는" 시나리오(C1)가 재현된다
    func restorePurchases() async throws -> BillingUserPlan? {
        self.didRestoreCalled = true
        if let restoreResult {
            self.userPlanSubject.send(restoreResult)
        }
        return self.restoreResult
    }

    // paywall 진입 시 유저 플랜을 재조회한다 — 실패하면 화면 렌더 게이트(PaywallScreenState)가
    // 본문을 막는다. 성공 값은 restorePurchases()와 동일하게 subject 에 push해 currentUserPlan
    // 릴레이(currentPlanId 미러링)까지 재현한다 (#739)
    func refreshUserPlan() async throws -> BillingUserPlan {
        self.didRefreshUserPlanCalled = true
        if let userPlanLoadError { throw userPlanLoadError }
        let plan = self.userPlanSubject.value ?? BillingUserPlan()
        self.userPlanSubject.send(plan)
        return plan
    }

    func startObservingTransactions() { }
    func stopObservingTransactions() { }
    func recoverUnfinishedTransactions() { }
    func hasUnfinishedTransactions() async -> Bool {
        self.didCheckUnfinishedCalled = true
        return self.hasUnfinished
    }

    func applyUnfinishedTransactions() async throws -> BillingUserPlan? {
        self.didApplyUnfinishedTimes += 1
        let applied = try self.applyUnfinishedResult.get()
        if let applied {
            self.userPlanSubject.send(applied)
        }
        return applied
    }

    var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
        self.userPlanSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
}
