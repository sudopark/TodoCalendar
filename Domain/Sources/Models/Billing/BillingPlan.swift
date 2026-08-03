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


extension BillingPlanId {

    // 티어 등급 — 값이 클수록 상위 플랜. 새 티어가 추가되면 이 표에만 반영하면
    // covers(_:) 를 쓰는 모든 곳(paywall 구매 가능 여부 등)이 함께 갱신된다
    private var rank: Int {
        switch self {
        case .free:     return 0
        case .standard: return 1
        case .lifetime: return 2
        }
    }

    // 이 플랜을 보유하면 other 플랜을 구매할 필요가 없는지 — 같은 등급이거나 상위 등급이면 true.
    // lifetime(최상위) 보유자에게 standard(하위) 구매 카드를 활성화하지 않기 위한 판정 (#739)
    public func covers(_ other: BillingPlanId) -> Bool {
        return self.rank >= other.rank
    }
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
