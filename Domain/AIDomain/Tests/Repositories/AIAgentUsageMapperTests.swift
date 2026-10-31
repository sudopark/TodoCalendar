//
//  AIAgentUsageMapperTests.swift
//  AIDomainTests
//
//  Created by sudo.park on 8/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import BillingDomainInterface
import BillingDomainTesting
@testable import AIDomain



// 플랜 정보 정본은 billingUserPlan 키 하나 — 매퍼가 usage 와 별도로 userPlan 을 노출해야
// usecase 가 그 키를 채울 수 있다 (#739)
struct AIAgentUsageMapperTests {

    private let stubPlan: BillingUserPlan = {
        var plan = BillingUserPlan()
        plan.planId = .lifetime
        return plan
    }()

    @Test func usageMapper_exposesUserPlanSeparatelyFromUsage() throws {
        // given
        let parser = StubBillingUserPlanResponseParser(stubPlan: self.stubPlan)
        let json: [String: Any] = [
            "input_tokens": 100, "output_tokens": 200, "daily_limit": 20000,
            "topup_remaining": 12300,
            "plan": ["id": "standard"]
        ]
        // when
        let mapper = try AIAgentUsageMapper(json: json, planParser: parser)
        // then
        #expect(parser.didParsedPlanJson?["id"] as? String == "standard")
        #expect(parser.didParsedTopupRemaining == 12300)
        #expect(mapper.userPlan == self.stubPlan)
        #expect(mapper.usage.dailyLimit == 20000)
    }

    @Test func usageMapper_whenNoPlanField_userPlanIsNil() throws {
        // given
        let parser = StubBillingUserPlanResponseParser(stubPlan: self.stubPlan)
        let json: [String: Any] = [
            "input_tokens": 100, "output_tokens": 200, "daily_limit": 20000
        ]
        // when
        let mapper = try AIAgentUsageMapper(json: json, planParser: parser)
        // then
        #expect(mapper.userPlan == nil)
        #expect(parser.didParsedPlanJson == nil)
    }
}
