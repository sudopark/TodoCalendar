//
//  BillingPlanIdRankTests.swift
//  Domain
//
//  Created by sudo.park on 8/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing

@testable import Domain


final class BillingPlanIdRankTests { }


// MARK: - 같은 등급·상위 등급 보유 시 커버됨

extension BillingPlanIdRankTests {

    @Test func covers_whenSamePlan_isTrue() {
        // given + when + then
        #expect(BillingPlanId.standard.covers(.standard) == true)
    }

    @Test func covers_whenHigherRankOwned_isTrue() {
        // given: lifetime(최상위) 보유
        // when + then: standard 도 커버 — 구매 카드가 활성화되면 안 된다
        #expect(BillingPlanId.lifetime.covers(.standard) == true)
        #expect(BillingPlanId.lifetime.covers(.free) == true)
    }
}


// MARK: - 하위 등급 보유 시 커버 안 됨

extension BillingPlanIdRankTests {

    @Test func covers_whenLowerRankOwned_isFalse() {
        // given: free 보유
        // when + then: standard·lifetime 은 커버되지 않는다 — 구매 가능해야 한다
        #expect(BillingPlanId.free.covers(.standard) == false)
        #expect(BillingPlanId.free.covers(.lifetime) == false)
        #expect(BillingPlanId.standard.covers(.lifetime) == false)
    }
}
