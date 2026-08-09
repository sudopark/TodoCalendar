//
//  StubBillingUsecase.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 8/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


final class StubBillingUsecase: BillingUsecase, @unchecked Sendable {

    // 실제 usecase처럼 nil 시작 — seeding 전엔 무방출(compactMap) 이 정상 상태
    let currentUserPlanSubject: CurrentValueSubject<BillingUserPlan?, Never>

    init(stubUserPlan: BillingUserPlan? = nil) {
        self.currentUserPlanSubject = .init(stubUserPlan)
    }

    func loadPlanOfferings() async throws -> [BillingPlanOffering] { [] }
    func loadTopupOfferings() async throws -> [BillingTopupOffering] { [] }

    func purchase(productId: String) async throws -> BillingPurchaseResult {
        throw RuntimeError("not imple")
    }

    func restorePurchases() async throws -> BillingUserPlan? { nil }

    func refreshUserPlan() async throws -> BillingUserPlan {
        self.currentUserPlanSubject.value ?? BillingUserPlan()
    }

    func startObservingTransactions() { }
    func stopObservingTransactions() { }
    func recoverUnfinishedTransactions() { }
    func hasUnfinishedTransactions() async -> Bool { false }
    func applyUnfinishedTransactions() async throws -> BillingUserPlan? { nil }

    var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
        self.currentUserPlanSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
}
