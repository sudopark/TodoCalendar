//
//  StubBillingUserPlanSource.swift
//  DomainTests
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import Domain


final class StubBillingUserPlanSource: BillingUserPlanSource, Sendable {

    private let plan: BillingUserPlan?

    init(plan: BillingUserPlan?) {
        self.plan = plan
    }

    func latestUserPlan() -> BillingUserPlan? {
        return self.plan
    }
}
