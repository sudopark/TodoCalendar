//
//  BillingUserPlanTests.swift
//  Domain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics

@testable import Domain


final class BillingUserPlanTests { }


// MARK: - 유료 판정

extension BillingUserPlanTests {

    @Test func isPaid_whenFree_isFalse() {
        // given
        let plan = BillingUserPlan() |> \.planId .~ .free

        // when + then
        #expect(plan.isPaid == false)
    }

    @Test func isPaid_whenStandard_isTrue() {
        // given
        let plan = BillingUserPlan() |> \.planId .~ .standard

        // when + then
        #expect(plan.isPaid == true)
    }

    @Test func isPaid_whenLifetime_isTrue() {
        // given
        let plan = BillingUserPlan() |> \.planId .~ .lifetime

        // when + then
        #expect(plan.isPaid == true)
    }

    @Test func isPaid_whenPlanIdUnknown_isNil() {
        // given: 앱이 모르는 플랜 id
        let plan = BillingUserPlan() |> \.planId .~ nil

        // when + then: 판단 불가 — 해석은 소비자 몫
        #expect(plan.isPaid == nil)
    }
}
