//
//  SpyBillingUserPlanStore.swift
//  BillingDomainTesting
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import BillingDomainInterface


public final class SpyBillingUserPlanStore: BillingUserPlanStore, @unchecked Sendable {

    private let planSubject: CurrentValueSubject<BillingUserPlan?, Never>
    public private(set) var didUpdatedPlan: BillingUserPlan?

    public init(plan: BillingUserPlan? = nil) {
        self.planSubject = .init(plan)
    }

    public func latestUserPlan() -> BillingUserPlan? {
        return self.planSubject.value
    }

    public func observePlan() -> AnyPublisher<BillingUserPlan?, Never> {
        return self.planSubject.eraseToAnyPublisher()
    }

    public func updatePlan(_ plan: BillingUserPlan) {
        self.didUpdatedPlan = plan
        self.planSubject.send(plan)
    }
}
