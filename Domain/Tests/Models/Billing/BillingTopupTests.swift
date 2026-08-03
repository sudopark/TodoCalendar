//
//  BillingTopupTests.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics

@testable import Domain


final class BillingTopupTests { }


// MARK: - 보너스 반영 총 크레딧

extension BillingTopupTests {

    @Test func topup_whenNoBonus_totalIsCreditsItself() {
        // given
        let topup = BillingTopup(productId: "topup.tier.1", credits: 100_000)
        // when + then
        #expect(topup.totalCredits == 100_000)
    }

    @Test func topup_whenBonusExists_totalIncludesBonus() {
        // given
        let topup = BillingTopup(productId: "topup.tier.2", credits: 550_000)
            |> \.bonusRate .~ 0.1
        // when + then
        #expect(topup.totalCredits == 605_000)
    }

    // 소수점 잔여는 반올림 — 서버가 Math.round 로 적립하므로 표시가 1 크레딧도 어긋나면 안 된다.
    // 절삭이면 150_001 이 나와 이 케이스가 깨진다
    @Test func topup_whenBonusMakesFraction_rounds() {
        // given
        let topup = BillingTopup(productId: "topup.tier.3", credits: 100_001)
            |> \.bonusRate .~ 0.5
        // when + then
        #expect(topup.totalCredits == 150_002)
    }
}
