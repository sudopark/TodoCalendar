//
//  StubBillingUsecase.swift
//  BillingDomainTesting
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions
import BillingDomainInterface



public final class StubBillingUsecase: BillingUsecase, @unchecked Sendable {

    public let currentUserPlanSubject: CurrentValueSubject<BillingUserPlan?, Never>

    public init(stubUserPlan: BillingUserPlan? = nil) {
        self.currentUserPlanSubject = .init(stubUserPlan)
    }

    public func loadPlanOfferings() async throws -> [BillingPlanOffering] { [] }
    public func loadTopupOfferings() async throws -> [BillingTopupOffering] { [] }

    public func purchase(productId: String) async throws -> BillingPurchaseResult {
        throw RuntimeError("not imple")
    }

    public func restorePurchases() async throws -> BillingRestoreResult { .nothingToRestore }

    public func refreshUserPlan() async throws -> BillingUserPlan {
        self.currentUserPlanSubject.value ?? BillingUserPlan()
    }

    public func startObservingTransactions() { }
    public func stopObservingTransactions() { }
    public func recoverUnfinishedTransactions() { }
    public func hasUnfinishedTransactions() async -> Bool { false }
    public func applyUnfinishedTransactions() async throws -> BillingUserPlan? { nil }

    public func latestUserPlan() -> BillingUserPlan? {
        return self.currentUserPlanSubject.value
    }

    public var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
        return self.currentUserPlanSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
}
