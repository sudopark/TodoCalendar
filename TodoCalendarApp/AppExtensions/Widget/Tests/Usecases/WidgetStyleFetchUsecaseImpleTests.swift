//
//  WidgetStyleFetchUsecaseImpleTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain

@testable import TodoCalendarAppWidget


final class WidgetStyleFetchUsecaseImpleTests {

    private let variant: WidgetVariant = .monthSmall
    private let customStyle: WidgetStyleId.Style = .custom(id: "c1")

    private func style(_ style: WidgetStyleId.Style, name: String? = nil) -> WidgetStyle {
        return WidgetStyle(
            id: .init(variant: self.variant, style: style),
            name: name,
            setting: self.variant.initialSetting!
        )
    }

    private func makeUsecase(
        saved: [WidgetStyle],
        plan: BillingUserPlan? = BillingUserPlan() |> \.planId .~ .free,
        licenseGrantedAt: Date? = nil,
        licenseDays: Int = 7,
        policy: AppPolicy? = nil,
        defaultPolicy: AppPolicy? = nil
    ) -> WidgetStyleFetchUsecaseImple {
        return WidgetStyleFetchUsecaseImple(
            styleRepository: StubWidgetStyleRepository(
                styles: Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            ),
            planRepository: StubBillingUserPlanRepository(plan: plan),
            licenseRepository: StubWidgetStyleLicenseRepository(
                license: licenseGrantedAt.map { .init(grantedAt: $0) }
            ),
            policyRepository: StubAppPolicyRepository(policy: policy),
            defaultPolicy: defaultPolicy
                ?? AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: licenseDays))
        )
    }

    private func thrownReason(_ action: () throws -> Void) -> PaidFeatureGateFailReason? {
        do {
            try action()
            return nil
        } catch let reason as PaidFeatureGateFailReason {
            return reason
        } catch {
            Issue.record(error)
            return nil
        }
    }
}


// MARK: - 스타일 한 건 읽기

extension WidgetStyleFetchUsecaseImpleTests {

    @Test("꾸미기 권한이 있으면 고른 스타일을 읽는다")
    func fetchStyle_whenAllowed_returnsSelected() throws {
        // given
        let saved = self.style(self.customStyle, name: "여름")
        let usecase = self.makeUsecase(
            saved: [self.style(.default, name: "기본"), saved],
            plan: BillingUserPlan() |> \.planId .~ .standard
        )

        // when
        let fetched = try usecase.fetchStyle(of: self.variant, selected: self.customStyle)

        // then
        #expect(fetched?.name == "여름")
    }

    @Test("고른 커스텀이 지워졌으면 기본 저장분을 읽는다")
    func fetchStyle_whenSelectedRemoved_returnsSavedDefault() throws {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(.default, name: "기본")],
            plan: BillingUserPlan() |> \.planId .~ .standard
        )

        // when
        let fetched = try usecase.fetchStyle(of: self.variant, selected: self.customStyle)

        // then
        #expect(fetched?.name == "기본")
    }

    @Test("저장분이 없으면 막힌 상태여도 던지지 않고 비어 돌아온다")
    func fetchStyle_whenNothingSaved_returnsNilWithoutThrowing() {
        // given
        let usecase = self.makeUsecase(saved: [])

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: .default) }

        // then
        #expect(reason == nil)
    }

    @Test("무료 플랜에 사용권이 없으면 꾸민 스타일 대신 위젯 꾸미기 사유를 던진다")
    func fetchStyle_whenFreeWithoutLicense_throwsCustomizeReason() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(self.customStyle)], licenseDays: 5)

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason == .init(feature: .customizeWidget, licenseDays: 5))
    }

    @Test("플랜을 모르면 무료로 보고 막는다")
    func fetchStyle_whenPlanUnknown_throwsCustomizeReason() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(self.customStyle)], plan: nil)

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason?.feature == .customizeWidget)
    }

    @Test("플랜을 몰라도 사용권이 유효하면 통과한다")
    func fetchStyle_whenPlanUnknownButLicensed_returnsSelected() throws {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(self.customStyle, name: "여름")],
            plan: nil,
            licenseGrantedAt: Date().addingTimeInterval(-3600)
        )

        // when
        let fetched = try usecase.fetchStyle(of: self.variant, selected: self.customStyle)

        // then
        #expect(fetched?.name == "여름")
    }

    @Test("기본을 골랐어도 꾸며 저장한 기본이면 막힐 때 위젯 꾸미기 사유를 던진다")
    func fetchStyle_whenSavedDefaultAndBlocked_throwsCustomizeReason() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(.default, name: "기본")])

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: .default) }

        // then
        #expect(reason?.feature == .customizeWidget)
    }

    @Test("사용권 기간이 지나면 다시 막는다")
    func fetchStyle_whenLicenseExpired_throwsCustomizeReason() {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(self.customStyle)],
            licenseGrantedAt: Date().addingTimeInterval(-8 * 24 * 3600),
            licenseDays: 7
        )

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason?.feature == .customizeWidget)
    }
}


// MARK: - 고를 후보

extension WidgetStyleFetchUsecaseImpleTests {

    @Test("후보는 기본 스타일을 맨 앞에 두고, 저장된 기본이 없으면 처음 설정으로 채운다")
    func fetchStyleCandidates_putsDefaultFirst() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(self.customStyle, name: "여름")])

        // when
        let candidates = usecase.fetchStyleCandidates(of: self.variant)

        // then
        #expect(candidates.map { $0.style.id.style } == [.default, self.customStyle])
    }

    @Test("꾸미기가 막히면 커스텀은 선택 불가이고, 꾸민 적 없는 기본은 선택 가능하다")
    func fetchStyleCandidates_whenBlocked_marksCustomUnselectableAndKeepsInitialDefault() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(self.customStyle)])

        // when
        let candidates = usecase.fetchStyleCandidates(of: self.variant)

        // then
        #expect(candidates.map { $0.isSelectable } == [true, false])
    }

    @Test("꾸미기가 막히면 꾸며 저장한 기본도 선택 불가로 표시한다")
    func fetchStyleCandidates_whenBlocked_marksSavedDefaultUnselectable() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(.default), self.style(self.customStyle)])

        // when
        let candidates = usecase.fetchStyleCandidates(of: self.variant)

        // then
        #expect(candidates.map { $0.isSelectable } == [false, false])
    }

    @Test("꾸미기 권한이 있으면 모든 후보가 선택 가능하다")
    func fetchStyleCandidates_whenAllowed_marksAllSelectable() {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(.default), self.style(self.customStyle)],
            plan: BillingUserPlan() |> \.planId .~ .standard
        )

        // when
        let candidates = usecase.fetchStyleCandidates(of: self.variant)

        // then
        #expect(candidates.map { $0.isSelectable } == [true, true])
    }
}


// MARK: - 정책 해석

extension WidgetStyleFetchUsecaseImpleTests {

    @Test("받은 정책의 기간이 있으면 주입한 기본값이 아니라 그 기간을 사유에 싣는다")
    func fetchStyle_whenPolicyReceived_usesReceivedDays() {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(self.customStyle)],
            licenseDays: 7,
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: 3))
        )

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason == .init(feature: .customizeWidget, licenseDays: 3))
    }

    @Test("받은 정책이 게이트를 껐으면 무료 플랜이라도 통과한다")
    func fetchStyle_whenPolicyDisabled_passes() {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(self.customStyle)],
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: 3))
        )

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason == nil)
    }

    @Test("사용권 기간이 0 이하면 무료 플랜이라도 통과한다", arguments: [0, -1])
    func fetchStyle_whenLicenseDaysNotPositive_passes(_ days: Int) {
        // given
        let usecase = self.makeUsecase(saved: [self.style(self.customStyle)], licenseDays: days)

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason == nil)
    }

    @Test("정책도 기본값도 판단할 수 없으면 통과한다")
    func fetchStyle_whenPolicyUndecidable_passes() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(self.customStyle)], defaultPolicy: AppPolicy())

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason == nil)
    }

    @Test("부여 시각이 지금보다 미래인 사용권은 유효하지 않다")
    func fetchStyle_whenLicenseGrantedInFuture_throwsCustomizeReason() {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(self.customStyle)],
            licenseGrantedAt: Date().addingTimeInterval(3600)
        )

        // when
        let reason = self.thrownReason { _ = try usecase.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(reason?.feature == .customizeWidget)
    }

    @Test("사용권은 부여 시각부터 n×24시간이 지나면 끝나고, 그 직전까지는 유효하다")
    func fetchStyle_licenseExpiresAtExactDays() {
        // given
        let days = 7
        let exactlyExpired = self.makeUsecase(
            saved: [self.style(self.customStyle)],
            licenseGrantedAt: Date().addingTimeInterval(-TimeInterval(days) * 24 * 3600),
            licenseDays: days
        )
        let justBefore = self.makeUsecase(
            saved: [self.style(self.customStyle)],
            licenseGrantedAt: Date().addingTimeInterval(-TimeInterval(days) * 24 * 3600 + 60),
            licenseDays: days
        )

        // when
        let expiredReason = self.thrownReason { _ = try exactlyExpired.fetchStyle(of: self.variant, selected: self.customStyle) }
        let validReason = self.thrownReason { _ = try justBefore.fetchStyle(of: self.variant, selected: self.customStyle) }

        // then
        #expect(expiredReason?.feature == .customizeWidget)
        #expect(validReason == nil)
    }
}
