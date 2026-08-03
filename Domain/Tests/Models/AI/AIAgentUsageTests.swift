//
//  AIAgentUsageTests.swift
//  Domain
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics

@testable import Domain


final class AIAgentUsageTests { }


// MARK: - credit 사용량 파생

extension AIAgentUsageTests {

    @Test func usage_whenCreditsUsedExists_useIt() {
        // given
        let usage = AIAgentUsage(input: 100, output: 200, limit: 5000)
            |> \.creditsUsed .~ 1234
        // when + then
        #expect(usage.usedCredits == 1234)
    }

    @Test func usage_whenCreditsUsedIsNil_fallbackToTokenSum() {
        // given
        let usage = AIAgentUsage(input: 100, output: 200, limit: 5000)
        // when + then
        #expect(usage.usedCredits == 300)
    }

    // 0은 서버가 내려주는 정상값(반올림 결과) — 부재와 구분해 폴백을 타지 않아야 한다
    @Test func usage_whenCreditsUsedIsZero_useZeroNotFallback() {
        // given
        let usage = AIAgentUsage(input: 100, output: 200, limit: 5000)
            |> \.creditsUsed .~ 0
        // when + then
        #expect(usage.usedCredits == 0)
        #expect(usage.usedRatio == 0)
    }

    @Test func usage_whenCreditsUsedIsNil_ratioIsTokenSumOverLimit() {
        // given
        let usage = AIAgentUsage(input: 1000, output: 250, limit: 5000)
        // when + then
        #expect(usage.usedRatio == 0.25)
    }

    @Test func usage_usedRatio_isUsedCreditsOverLimit() {
        // given
        let usage = AIAgentUsage(input: 0, output: 0, limit: 5000)
            |> \.creditsUsed .~ 1250
        // when + then
        #expect(usage.usedRatio == 0.25)
    }

    @Test func usage_whenUsedExceedsLimit_ratioClampedToOne() {
        // given
        let usage = AIAgentUsage(input: 0, output: 0, limit: 5000)
            |> \.creditsUsed .~ 6000
        // when + then
        #expect(usage.usedRatio == 1.0)
    }

    @Test func usage_whenLimitIsZero_ratioIsZero() {
        // given
        let usage = AIAgentUsage(input: 100, output: 200, limit: 0)
        // when + then
        #expect(usage.usedRatio == 0)
    }
}
