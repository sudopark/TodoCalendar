//
//  StubBillingUserPlanRepository.swift
//  DomainTests
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import Domain


final class StubBillingUserPlanRepository: BillingUserPlanRepository, @unchecked Sendable {

    private var plan: BillingUserPlan?

    private(set) var didFetchPlan: Bool = false
    private(set) var didUpdatedPlan: BillingUserPlan?

    init(plan: BillingUserPlan? = nil) {
        self.plan = plan
    }

    func fetchPlan() -> BillingUserPlan? {
        self.didFetchPlan = true
        return self.plan
    }

    func updatePlan(_ plan: BillingUserPlan) {
        self.didUpdatedPlan = plan
        self.plan = plan
    }
}
