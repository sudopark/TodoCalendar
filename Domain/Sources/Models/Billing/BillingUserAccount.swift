//
//  BillingUserAccount.swift
//  Domain
//
//  Created by sudo.park on 8/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// GET /v1/billing/user-plan 응답 전체. appAccountToken 은 플랜 속성이 아니라 결제 계정
// 식별자라 BillingUserPlan 밖에 둔다 — 그 모델은 구매·위임 응답도 함께 쓰는데 토큰은 안 온다
public struct BillingUserAccount: Sendable, Equatable {

    public var plan: BillingUserPlan
    public var appAccountToken: UUID?

    public init(plan: BillingUserPlan) {
        self.plan = plan
    }
}
