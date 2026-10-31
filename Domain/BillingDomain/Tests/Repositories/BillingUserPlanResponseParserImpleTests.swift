//
//  BillingUserPlanResponseParserImpleTests.swift
//  BillingDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import BillingDomainInterface
@testable import BillingDomain


struct BillingUserPlanResponseParserImpleTests {

    private let parser = BillingUserPlanResponseParserImple()

    @Test func parser_parsesPlanIdScheduledChangeAndTopup() {
        // given
        let json: [String: Any] = [
            "id": "standard",
            "scheduled_change": [
                "plan_id": "free",
                "effective_at": "2026-08-26T00:00:00.000Z"
            ]
        ]
        // when
        let plan = self.parser.userPlan(from: json, topupRemaining: 12300)
        // then
        #expect(plan.planId == .standard)
        #expect(plan.topupRemaining == 12300)
        #expect(plan.scheduledChange?.planId == .free)
        #expect(plan.scheduledChange?.effectiveAt.timeIntervalSince1970 == 1787702400)
    }

    // 모르는 플랜 id는 파싱 실패로 두고 나머지 필드는 살린다 — 칩만 안 뜨고 게이지는 정상
    @Test func parser_whenPlanIdIsUnknown_planIdIsNilButTopupRemains() {
        // given
        let json: [String: Any] = ["id": "enterprise", "scheduled_change": NSNull()]
        // when
        let plan = self.parser.userPlan(from: json, topupRemaining: 500)
        // then
        #expect(plan.planId == nil)
        #expect(plan.topupRemaining == 500)
        #expect(plan.scheduledChange == nil)
    }
}
