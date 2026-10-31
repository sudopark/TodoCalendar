//
//  BillingUserPlanResponseParser.swift
//  BillingDomainInterface
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol BillingUserPlanResponseParser: Sendable {

    func userPlan(from planJson: [String: Any], topupRemaining: Int?) -> BillingUserPlan
}
