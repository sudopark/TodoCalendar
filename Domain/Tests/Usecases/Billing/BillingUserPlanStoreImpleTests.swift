//
//  BillingUserPlanStoreImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Combine
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


final class BillingUserPlanStoreImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private var stubRepository: StubBillingUserPlanRepository!
    private var sharedDataStore: SharedDataStore!

    private func makeStore() -> BillingUserPlanStoreImple {
        self.stubRepository = StubBillingUserPlanRepository()
        self.sharedDataStore = SharedDataStore()
        return BillingUserPlanStoreImple(
            sharedDataStore: self.sharedDataStore, repository: self.stubRepository
        )
    }

    private func userPlan(_ planId: BillingPlanId) -> BillingUserPlan {
        return BillingUserPlan() |> \.planId .~ planId
    }
}


// MARK: - 기록

extension BillingUserPlanStoreImpleTests {

    @Test("기록하면 메모리와 영속에 함께 남는다")
    func store_updatePlan_putsToMemoryAndPersists() {
        // given
        let store = self.makeStore()

        // when
        store.updatePlan(self.userPlan(.standard))

        // then
        #expect(store.latestUserPlan()?.planId == .standard)
        #expect(self.stubRepository.didUpdatedPlan?.planId == .standard)
    }

    @Test("뒤에 기록한 플랜이 앞의 것을 덮는다")
    func store_updatePlanTwice_keepsLatest() {
        // given
        let store = self.makeStore()

        // when
        store.updatePlan(self.userPlan(.standard))
        store.updatePlan(self.userPlan(.lifetime))

        // then
        #expect(store.latestUserPlan()?.planId == .lifetime)
        #expect(self.stubRepository.didUpdatedPlan?.planId == .lifetime)
    }
}


// MARK: - 조회·구독

extension BillingUserPlanStoreImpleTests {

    @Test("조회는 영속이 아니라 메모리 값을 준다")
    func store_latestUserPlan_readsMemoryValue() {
        // given
        let store = self.makeStore()

        // when
        let beforeSeed = store.latestUserPlan()
        self.sharedDataStore.put(
            BillingUserPlan.self,
            key: ShareDataKeys.billingUserPlan.rawValue,
            self.userPlan(.lifetime)
        )
        let afterSeed = store.latestUserPlan()

        // then
        #expect(beforeSeed == nil)
        #expect(afterSeed?.planId == .lifetime)
        #expect(self.stubRepository.didFetchPlan == false)
    }

    @Test("구독은 값이 없는 동안 nil 을 내고 기록에 이어 새 값을 낸다")
    func store_observePlan_emitsNilWhenAbsentThenNewPlan() async throws {
        // given
        let store = self.makeStore()
        let expect = expectConfirm("nil 과 기록한 플랜을 차례로 낸다")
        expect.count = 2

        // when
        let planIds = try await self.outputs(
            expect, for: store.observePlan().map { $0?.planId }
        ) {
            store.updatePlan(self.userPlan(.standard))
        }

        // then
        #expect(planIds == [nil, .standard])
    }
}
