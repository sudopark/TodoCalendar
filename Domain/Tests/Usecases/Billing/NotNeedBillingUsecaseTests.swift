//
//  NotNeedBillingUsecaseTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Extensions
import UnitTestHelpKit

@testable import Domain


final class NotNeedBillingUsecaseTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeUsecaseWithStore() -> (NotNeedBillingUsecase, SharedDataStore) {
        let store = SharedDataStore()
        let usecase = NotNeedBillingUsecase(sharedDataStore: store)
        return (usecase, store)
    }
}


// MARK: - 미로그인 세션은 생성 시점에 free 로 확정된다

extension NotNeedBillingUsecaseTests {

    @Test func usecase_whenCreated_seedFreePlan() {
        // given
        // when
        let (_, store) = self.makeUsecaseWithStore()
        // then
        let plan = store.value(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue)
        #expect(plan?.planId == .free)
    }

    @Test func usecase_whenCreated_latestUserPlanIsFree() {
        // given
        // when
        let (usecase, _) = self.makeUsecaseWithStore()
        // then
        #expect(usecase.latestUserPlan()?.planId == .free)
    }

    @Test func usecase_currentUserPlan_emitFreePlan() async throws {
        // given
        let expect = expectConfirm("미로그인 세션은 첫 방출부터 free")
        let (usecase, _) = self.makeUsecaseWithStore()
        // when
        let plan = try await self.firstOutput(expect, for: usecase.currentUserPlan)
        // then
        #expect(plan?.planId == .free)
    }
}
