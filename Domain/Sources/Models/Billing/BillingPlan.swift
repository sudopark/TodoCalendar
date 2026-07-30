//
//  BillingPlan.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum BillingPlanId: String, Sendable {
    case free
    case standard
    case lifetime
}


// GET /v1/billing/plans 의 한 항목. 가격은 없다 — StoreKit 이 현지화 가격을 답한다
public struct BillingPlan: Sendable, Equatable {

    public let id: BillingPlanId
    public let dailyLimit: Int
    // free 는 상품이 없다
    public var productId: String?
    public var isTopupAllowed: Bool = false

    public init(id: BillingPlanId, dailyLimit: Int) {
        self.id = id
        self.dailyLimit = dailyLimit
    }
}
