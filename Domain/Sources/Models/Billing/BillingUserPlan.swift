//
//  BillingUserPlan.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// 유저의 현재 발효 플랜. GET /v1/billing/plans 가 아니라
// GET /v1/ai/usage 의 plan 필드 · POST /v1/billing/purchases 응답이 같은 스키마로 내려준다
public struct BillingUserPlan: Sendable, Equatable {

    // 앱이 모르는 플랜 id 는 nil — 신규 플랜이 서버에 먼저 배포돼도 나머지 필드는 살린다
    public var planId: BillingPlanId?
    public var scheduledChange: ScheduledChange?
    public var topupRemaining: Int?

    public init() { }

    // 하향 예약 — 다음 차수부터 적용될 플랜 변경
    public struct ScheduledChange: Sendable, Equatable {

        public let planId: BillingPlanId
        public let effectiveAt: Date

        public init(planId: BillingPlanId, effectiveAt: Date) {
            self.planId = planId
            self.effectiveAt = effectiveAt
        }
    }
}
