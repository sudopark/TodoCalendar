//
//  AIAgentUsageTests.swift
//  Domain
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


struct AIAgentUsageTests {

    private func usage(used: Int, limit: Int) -> AIAgentUsage {
        return AIAgentUsage(input: 0, output: 0, limit: limit)
            |> \.creditsUsed .~ used
    }

    private func plan(topupRemaining: Int?) -> BillingUserPlan {
        return BillingUserPlan()
            |> \.topupRemaining .~ topupRemaining
    }
}


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


// MARK: - 일일 한도 기준 판정

extension AIAgentUsageTests {

    @Test("한도 미만이면 top-up 잔량과 무관하게 소진 아님", arguments: [0, 500])
    func usage_whenUnderDailyLimit_isNotExhausted(_ topup: Int) {
        // given
        let usage = self.usage(used: 2999, limit: 3000)

        // when
        let isExhausted = usage.isCreditExhausted(topupRemaining: topup)

        // then
        #expect(isExhausted == false)
    }

    @Test("한도에 정확히 도달하고 top-up 잔량이 없으면 소진")
    func usage_whenReachedDailyLimitWithoutTopup_isExhausted() {
        // given
        let usage = self.usage(used: 3000, limit: 3000)

        // when
        let isExhausted = usage.isCreditExhausted(topupRemaining: 0)

        // then
        #expect(isExhausted == true)
    }

    @Test("한도를 넘겨도 top-up 잔량이 남았으면 소진 아님")
    func usage_whenOverDailyLimitButTopupRemains_isNotExhausted() {
        // given
        let usage = self.usage(used: 13000, limit: 10000)

        // when
        let isExhausted = usage.isCreditExhausted(topupRemaining: 2000)

        // then
        #expect(isExhausted == false)
    }
}


// MARK: - 값 불명 구간은 막지 않는다 (fail-open)

extension AIAgentUsageTests {

    @Test("top-up 잔량이 불명이면 한도를 넘겨도 소진 아님")
    func usage_whenTopupRemainingIsUnknown_isNotExhausted() {
        // given
        let usage = self.usage(used: 13000, limit: 10000)

        // when
        let isExhausted = usage.isCreditExhausted(topupRemaining: nil)

        // then
        #expect(isExhausted == false)
    }

    @Test("일일 한도가 0(미설정)이면 소진 아님")
    func usage_whenDailyLimitIsNotConfigured_isNotExhausted() {
        // given
        let usage = self.usage(used: 100, limit: 0)

        // when
        let isExhausted = usage.isCreditExhausted(topupRemaining: 0)

        // then
        #expect(isExhausted == false)
    }
}


// MARK: - 조회 응답에서 바로 파생

extension AIAgentUsageTests {

    @Test("응답의 usage·plan 조합으로 소진 판정")
    func loadResult_derivesExhaustionFromUsageAndPlan() {
        // given
        let exhausted = AIAgentUsageLoadResult(
            usage: self.usage(used: 3000, limit: 3000),
            userPlan: self.plan(topupRemaining: 0)
        )
        let hasTopup = AIAgentUsageLoadResult(
            usage: self.usage(used: 3000, limit: 3000),
            userPlan: self.plan(topupRemaining: 100)
        )

        // when + then
        #expect(exhausted.isCreditExhausted == true)
        #expect(hasTopup.isCreditExhausted == false)
    }

    @Test("응답에 plan이 없으면 소진 아님")
    func loadResult_whenPlanIsMissing_isNotExhausted() {
        // given
        let result = AIAgentUsageLoadResult(
            usage: self.usage(used: 3000, limit: 3000),
            userPlan: nil
        )

        // when
        let isExhausted = result.isCreditExhausted

        // then
        #expect(isExhausted == false)
    }
}
