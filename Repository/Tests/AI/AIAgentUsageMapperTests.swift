//
//  AIAgentUsageMapperTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain

@testable import Repository


// 플랜 정보 정본은 billingUserPlan 키 하나 — 매퍼가 usage 와 별도로 userPlan 을 노출해야
// usecase 가 그 키를 채울 수 있다 (#739)
struct AIAgentUsageMapperTests {

    @Test func usageMapper_exposesUserPlanSeparatelyFromUsage() throws {
        // given
        let json: [String: Any] = [
            "input_tokens": 100, "output_tokens": 200, "daily_limit": 20000,
            "topup_remaining": 12300,
            "plan": ["id": "standard"]
        ]
        // when
        let mapper = try AIAgentUsageMapper(json: json)
        // then
        #expect(mapper.userPlan?.planId == .standard)
        #expect(mapper.userPlan?.topupRemaining == 12300)
    }

    @Test func usageMapper_whenNoPlanField_userPlanIsNil() throws {
        // given
        let json: [String: Any] = [
            "input_tokens": 100, "output_tokens": 200, "daily_limit": 20000
        ]
        // when
        let mapper = try AIAgentUsageMapper(json: json)
        // then
        #expect(mapper.userPlan == nil)
    }
}
