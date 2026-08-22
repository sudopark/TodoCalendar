//
//  BillingUserPlanConfirmationUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


final class BillingUserPlanConfirmationUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeUsecase() -> (BillingUserPlanConfirmationUsecaseImple, SharedDataStore) {
        let sharedDataStore = SharedDataStore()
        let usecase = BillingUserPlanConfirmationUsecaseImple(sharedDataStore: sharedDataStore)
        return (usecase, sharedDataStore)
    }
}


// MARK: - 플랜 미저장 → 확정 상태 스트림

extension BillingUserPlanConfirmationUsecaseImpleTests {

    @Test func usecase_whenPlanNotStored_emitUnconfirmed() async throws {
        // given
        let expect = expectConfirm("플랜이 저장되지 않았으면 unconfirmed 방출")
        let (usecase, _) = self.makeUsecase()

        // when
        let confirmation = try await self.firstOutput(expect, for: usecase.userPlanConfirmation)

        // then
        #expect(confirmation == .unconfirmed)
    }

    @Test func usecase_whenPlanStored_emitConfirmedPlan() async throws {
        // given
        let expect = expectConfirm("플랜이 저장되면 confirmed(plan) 방출")
        expect.count = 2
        let (usecase, sharedDataStore) = self.makeUsecase()
        let plan = BillingUserPlan() |> \.planId .~ .standard

        // when
        let confirmations = try await self.outputs(expect, for: usecase.userPlanConfirmation) {
            sharedDataStore.put(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue, plan)
        }

        // then
        #expect(confirmations == [.unconfirmed, .confirmed(plan)])
    }

    @Test func usecase_whenPlanCleared_emitUnconfirmedAgain() async throws {
        // given
        let expect = expectConfirm("플랜이 지워지면 다시 unconfirmed 방출")
        expect.count = 3
        let (usecase, sharedDataStore) = self.makeUsecase()
        let plan = BillingUserPlan() |> \.planId .~ .free

        // when
        let confirmations = try await self.outputs(expect, for: usecase.userPlanConfirmation) {
            sharedDataStore.put(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue, plan)
            sharedDataStore.delete(ShareDataKeys.billingUserPlan.rawValue)
        }

        // then
        #expect(confirmations == [.unconfirmed, .confirmed(plan), .unconfirmed])
    }

    // confirmation(expectedCount:) 은 정확한 호출 횟수를 요구해 "예상보다 더 안 온다"를 표현할
    // 수 없다 — 직접 sink 로 모으고 두 put 이 전파될 시간만큼 기다려 중복 부재를 확인한다
    @Test func usecase_whenSamePlanPutAgain_notEmitDuplicated() async throws {
        // given
        let (usecase, sharedDataStore) = self.makeUsecase()
        let plan = BillingUserPlan() |> \.planId .~ .free
        let collected = ConfirmationCollector<BillingUserPlanConfirmation>()
        usecase.userPlanConfirmation
            .sink { collected.append($0) }
            .store(in: &self.cancelBag)

        // when
        sharedDataStore.put(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue, plan)
        sharedDataStore.put(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue, plan)
        try await Task.sleep(for: .milliseconds(300))

        // then
        #expect(collected.snapshot() == [.unconfirmed, .confirmed(plan)])
    }
}


private final class ConfirmationCollector<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []

    func append(_ item: T) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.items.append(item)
    }

    func snapshot() -> [T] {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.items
    }
}


// MARK: - isFreeConfirmed 판정

extension BillingUserPlanConfirmationUsecaseImpleTests {

    @Test(
        "isFreeConfirmed 판정",
        arguments: [
            (BillingUserPlanConfirmation.unconfirmed, false),
            (.confirmed(BillingUserPlan() |> \.planId .~ .free), true),
            (.confirmed(BillingUserPlan() |> \.planId .~ .standard), false),
            (.confirmed(BillingUserPlan() |> \.planId .~ .lifetime), false),
            (.confirmed(BillingUserPlan()), false)
        ]
    )
    func confirmation_isFreeConfirmed(
        _ pair: (BillingUserPlanConfirmation, Bool)
    ) {
        // given
        let (confirmation, expected) = pair

        // when
        let isFreeConfirmed = confirmation.isFreeConfirmed()

        // then
        #expect(isFreeConfirmed == expected)
    }
}
