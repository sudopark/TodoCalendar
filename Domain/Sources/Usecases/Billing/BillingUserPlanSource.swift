//
//  BillingUserPlanSource.swift
//  Domain
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol BillingUserPlanSource: Sendable {

    func latestUserPlan() -> BillingUserPlan?
}
