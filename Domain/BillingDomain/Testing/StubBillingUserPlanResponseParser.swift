//
//  StubBillingUserPlanResponseParser.swift
//  BillingDomainTesting
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import BillingDomainInterface


public final class StubBillingUserPlanResponseParser: BillingUserPlanResponseParser, @unchecked Sendable {

    public var stubPlan: BillingUserPlan
    public private(set) var didParsedPlanJson: [String: Any]?
    public private(set) var didParsedTopupRemaining: Int?

    public init(stubPlan: BillingUserPlan = BillingUserPlan()) {
        self.stubPlan = stubPlan
    }

    public func userPlan(from planJson: [String: Any], topupRemaining: Int?) -> BillingUserPlan {
        self.didParsedPlanJson = planJson
        self.didParsedTopupRemaining = topupRemaining
        return self.stubPlan
    }
}
