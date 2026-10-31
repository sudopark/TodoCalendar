//
//  BillingUserPlanResponseParserImple.swift
//  BillingDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import BillingDomainInterface


public struct BillingUserPlanResponseParserImple: BillingUserPlanResponseParser {

    public init() { }

    public func userPlan(from planJson: [String: Any], topupRemaining: Int?) -> BillingUserPlan {
        return BillingUserPlanMapper(json: planJson, topupRemaining: topupRemaining).userPlan
    }
}
