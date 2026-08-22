//
//  AdDisplayGateTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Foundation
import Prelude
import Optics
import Domain
import UnitTestHelpKit

@testable import TodoCalendarApp


final class AdDisplayGateTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
}


// MARK: - 구독 전 fail-closed

extension AdDisplayGateTests {

    @Test func gate_whenUnderlyingUsecaseNeverEmits_canShowAdNowStaysFalse() {
        // given
        let stub = StubNeverEmittingBillingUserPlanConfirmationUsecase()

        // when
        let gate = AdDisplayGate(userPlanConfirmationUsecase: stub)

        // then
        #expect(gate.canShowAdNow == false)
    }

    @Test func gate_beforeAnyConfirmation_notAllowAd() {
        // given
        let mock = MockBillingUserPlanConfirmationUsecase()

        // when
        let gate = AdDisplayGate(userPlanConfirmationUsecase: mock)

        // then
        #expect(gate.canShowAdNow == false)
    }
}


// MARK: - 확정 상태별 판정

extension AdDisplayGateTests {

    @Test func gate_whenFreeConfirmed_allowAd() async throws {
        // given
        let mock = MockBillingUserPlanConfirmationUsecase()
        let gate = AdDisplayGate(userPlanConfirmationUsecase: mock)

        // when
        let expect = self.expectConfirm("free 확정 시 허용")
        expect.count = 2
        let values = try await self.outputs(expect, for: gate.canShowAd) {
            mock.subject.send(.confirmed(BillingUserPlan() |> \.planId .~ .free))
        }

        // then
        #expect(values == [false, true])
        #expect(gate.canShowAdNow == true)
    }

    @Test(arguments: [BillingPlanId.standard, .lifetime])
    func gate_whenPaidConfirmed_notAllowAd(_ planId: BillingPlanId) async throws {
        // given
        let mock = MockBillingUserPlanConfirmationUsecase()
        let gate = AdDisplayGate(userPlanConfirmationUsecase: mock)

        // when
        let expect = self.expectConfirm("유료 확정 시 비허용: \(planId.rawValue)")
        let values = try await self.outputs(expect, for: gate.canShowAd) {
            mock.subject.send(.confirmed(BillingUserPlan() |> \.planId .~ planId))
        }

        // then
        #expect(values == [false])
        #expect(gate.canShowAdNow == false)
    }

    @Test func gate_whenPlanIdIsUnknown_notAllowAd() async throws {
        // given
        let mock = MockBillingUserPlanConfirmationUsecase()
        let gate = AdDisplayGate(userPlanConfirmationUsecase: mock)

        // when
        let expect = self.expectConfirm("모르는 planId 는 비허용")
        let values = try await self.outputs(expect, for: gate.canShowAd) {
            mock.subject.send(.confirmed(BillingUserPlan()))
        }

        // then
        #expect(values == [false])
        #expect(gate.canShowAdNow == false)
    }
}


// MARK: - 세션 중 전환

extension AdDisplayGateTests {

    @Test func gate_whenTurnedPaidDuringSession_stopAllowingAd() async throws {
        // given
        let mock = MockBillingUserPlanConfirmationUsecase()
        let gate = AdDisplayGate(userPlanConfirmationUsecase: mock)

        // when
        let expect = self.expectConfirm("free 확정 뒤 유료 전환 시 즉시 뒤집힌다")
        expect.count = 3
        let values = try await self.outputs(expect, for: gate.canShowAd) {
            mock.subject.send(.confirmed(BillingUserPlan() |> \.planId .~ .free))
            mock.subject.send(.confirmed(BillingUserPlan() |> \.planId .~ .standard))
        }

        // then
        #expect(values == [false, true, false])
    }

    @Test func gate_whenConfirmedPlanChangesButStillPaid_doesNotReemitCanShowAd() async throws {
        // given
        let mock = MockBillingUserPlanConfirmationUsecase()
        mock.subject.send(.confirmed(BillingUserPlan() |> \.planId .~ .standard))
        let gate = AdDisplayGate(userPlanConfirmationUsecase: mock)

        // when
        let expect = self.expectConfirm("유료 플랜 종류 변경은 재방출 없음")
        let values = try await self.outputs(expect, for: gate.canShowAd) {
            mock.subject.send(.confirmed(BillingUserPlan() |> \.planId .~ .lifetime))
        }

        // then
        #expect(values == [false])
    }
}


// MARK: - Doubles

private final class MockBillingUserPlanConfirmationUsecase: BillingUserPlanConfirmationUsecase, @unchecked Sendable {
    let subject = CurrentValueSubject<BillingUserPlanConfirmation, Never>(.unconfirmed)
    var userPlanConfirmation: AnyPublisher<BillingUserPlanConfirmation, Never> {
        return self.subject.eraseToAnyPublisher()
    }
}

private final class StubNeverEmittingBillingUserPlanConfirmationUsecase: BillingUserPlanConfirmationUsecase, @unchecked Sendable {
    var userPlanConfirmation: AnyPublisher<BillingUserPlanConfirmation, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }
}
