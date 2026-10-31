//
//  StubBillingUserPlanRepository.swift
//  BillingDomainTesting
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import BillingDomainInterface



public final class StubBillingUserPlanRepository: BillingUserPlanRepository, @unchecked Sendable {

    private var plan: BillingUserPlan?

    public private(set) var didFetchPlan: Bool = false
    public private(set) var didUpdatedPlan: BillingUserPlan?

    public init(plan: BillingUserPlan? = nil) {
        self.plan = plan
    }

    public func fetchPlan() -> BillingUserPlan? {
        self.didFetchPlan = true
        return self.plan
    }

    public func updatePlan(_ plan: BillingUserPlan) {
        self.didUpdatedPlan = plan
        self.plan = plan
    }
}
