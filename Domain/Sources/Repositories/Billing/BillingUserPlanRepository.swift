//
//  BillingUserPlanRepository.swift
//  Domain
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol BillingUserPlanRepository: Sendable {

    func fetchPlan() -> BillingUserPlan?
    func updatePlan(_ plan: BillingUserPlan)
}
