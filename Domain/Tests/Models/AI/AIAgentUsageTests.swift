//
//  AIAgentUsageTests.swift
//  Domain
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing

@testable import Domain


final class AIAgentUsageTests { }


// MARK: - 사용량 파생

extension AIAgentUsageTests {

    @Test func usage_usedTokens_isSumOfInputAndOutput() {
        // given
        let usage = AIAgentUsage(input: 100, output: 200, limit: 5000)
        // when + then
        #expect(usage.usedTokens == 300)
    }

    @Test func usage_usedRatio_isUsedOverLimit() {
        // given
        let usage = AIAgentUsage(input: 1000, output: 250, limit: 5000)
        // when + then
        #expect(usage.usedRatio == 0.25)
    }

    @Test func usage_whenUsedExceedsLimit_ratioClampedToOne() {
        // given
        let usage = AIAgentUsage(input: 6000, output: 0, limit: 5000)
        // when + then
        #expect(usage.usedRatio == 1.0)
    }

    @Test func usage_whenLimitIsZero_ratioIsZero() {
        // given
        let usage = AIAgentUsage(input: 100, output: 0, limit: 0)
        // when + then
        #expect(usage.usedRatio == 0)
    }
}
