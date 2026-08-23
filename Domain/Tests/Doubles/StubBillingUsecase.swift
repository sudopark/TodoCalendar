//
//  StubBillingUsecase.swift
//  DomainTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions

@testable import Domain


final class StubBillingUsecase: BillingUsecase, @unchecked Sendable {

    let currentUserPlanSubject: CurrentValueSubject<BillingUserPlan?, Never>

    init(stubUserPlan: BillingUserPlan? = nil) {
        self.currentUserPlanSubject = .init(stubUserPlan)
    }

    func loadPlanOfferings() async throws -> [BillingPlanOffering] { [] }
    func loadTopupOfferings() async throws -> [BillingTopupOffering] { [] }

    func purchase(productId: String) async throws -> BillingPurchaseResult {
        throw RuntimeError("not imple")
    }

    func restorePurchases() async throws -> BillingRestoreResult { .nothingToRestore }

    func refreshUserPlan() async throws -> BillingUserPlan {
        self.currentUserPlanSubject.value ?? BillingUserPlan()
    }

    func startObservingTransactions() { }
    func stopObservingTransactions() { }
    func recoverUnfinishedTransactions() { }
    func hasUnfinishedTransactions() async -> Bool { false }
    func applyUnfinishedTransactions() async throws -> BillingUserPlan? { nil }

    func latestUserPlan() -> BillingUserPlan? {
        return self.currentUserPlanSubject.value
    }

    var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
        return self.currentUserPlanSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
}
