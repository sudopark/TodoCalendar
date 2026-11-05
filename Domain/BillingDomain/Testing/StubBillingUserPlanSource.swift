//
//  StubBillingUserPlanSource.swift
//  BillingDomainTesting
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import BillingDomainInterface



public final class StubBillingUserPlanSource: BillingUserPlanSource, Sendable {

    private let plan: BillingUserPlan?

    public init(plan: BillingUserPlan?) {
        self.plan = plan
    }

    public func latestUserPlan() -> BillingUserPlan? {
        return self.plan
    }
}
