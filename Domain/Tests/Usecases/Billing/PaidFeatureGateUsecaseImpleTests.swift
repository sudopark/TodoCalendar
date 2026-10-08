//
//  PaidFeatureGateUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


final class PaidFeatureGateUsecaseImpleTests {

    private let now = Date(timeIntervalSince1970: 1_787_000_000)
    private let licenseDays = 7
    private let widgetLicenseDays = 5
    private let paidTheme: ColorSetKeys = .appTheme(.tomato)

    private var stubLicenseRepository: StubColorThemeLicenseRepository!
    private var stubWidgetLicenseRepository: StubWidgetStyleLicenseRepository!

    private func date(daysFromNow days: Double) -> Date {
        return self.now.addingTimeInterval(days * 24 * 3600)
    }

    private func userPlan(_ planId: BillingPlanId?) -> BillingUserPlan {
        return BillingUserPlan() |> \.planId .~ planId
    }

    private let injectedDefault = AppPolicy(
        colorThemeLicense: .init(isEnabled: true, licenseDays: 30),
        widgetStyleLicense: .init(isEnabled: true, licenseDays: 21)
    )

    private func makeUsecase(
        plan: BillingUserPlan?,
        grantedDaysFromNow: Double? = nil,
        widgetGrantedDaysFromNow: Double? = nil,
        policy: AppPolicy? = AppPolicy(
            colorThemeLicense: .init(isEnabled: true, licenseDays: 7),
            widgetStyleLicense: .init(isEnabled: true, licenseDays: 5)
        ),
        defaultPolicy: AppPolicy? = nil
    ) -> PaidFeatureGateUsecaseImple {
        self.stubLicenseRepository = StubColorThemeLicenseRepository(
            license: grantedDaysFromNow.map { .init(grantedAt: self.date(daysFromNow: $0)) }
        )
        self.stubWidgetLicenseRepository = StubWidgetStyleLicenseRepository(
            license: widgetGrantedDaysFromNow.map { .init(grantedAt: self.date(daysFromNow: $0)) }
        )
        return PaidFeatureGateUsecaseImple(
            billingUsecase: StubBillingUsecase(stubUserPlan: plan),
            licenseRepository: self.stubLicenseRepository,
            widgetStyleLicenseRepository: self.stubWidgetLicenseRepository,
            policyRepository: StubAppPolicyRepository(policy: policy),
            defaultPolicy: defaultPolicy ?? self.injectedDefault
        )
    }
}


// MARK: - 컬러 테마를 광고 없이 쓸 수 있나

extension PaidFeatureGateUsecaseImpleTests {

    @Test("무료 테마는 무료 플랜에 사용권이 없어도 항상 허용한다", arguments: [
        ColorSetKeys.systemTheme, .defaultLight, .defaultDark
    ])
    func canApplyColorTheme_freeTheme_alwaysTrue(_ key: ColorSetKeys) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = usecase.canApplyColorThemeWithoutAd(key, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("plan 을 아직 못 받았으면 유료 테마도 허용한다")
    func canApplyColorTheme_paidTheme_whenPlanPending_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: nil)

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("앱이 모르는 plan 이면 유료 테마도 허용한다")
    func canApplyColorTheme_paidTheme_whenPlanUnknown_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(nil))

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("유료 plan 은 사용권이 없어도 유료 테마를 허용한다", arguments: [
        BillingPlanId.standard, .lifetime
    ])
    func canApplyColorTheme_paidTheme_whenPaid_isTrue(_ planId: BillingPlanId) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(planId))

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 에 사용권 기록이 없으면 유료 테마를 허용하지 않는다")
    func canApplyColorTheme_paidTheme_whenFreeAndNoLicense_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == false)
    }

    @Test("무료 plan 이라도 사용권이 유효하면 유료 테마를 허용한다")
    func canApplyColorTheme_paidTheme_whenFreeAndLicenseValid_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -3)

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 의 사용권이 만료되면 유료 테마를 허용하지 않는다")
    func canApplyColorTheme_paidTheme_whenFreeAndLicenseExpired_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -8)

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == false)
    }

    @Test("사용권은 부여 시각부터 정확히 n×24시간이 지난 순간에 만료된다")
    func canApplyColorTheme_licenseBoundary_expiresExactlyAtLicenseDays() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: 0)
        let justBefore = self.now.addingTimeInterval(TimeInterval(self.licenseDays * 24 * 3600) - 1)
        let exactly = self.now.addingTimeInterval(TimeInterval(self.licenseDays * 24 * 3600))

        // when
        let canJustBefore = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: justBefore)
        let canExactly = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: exactly)

        // then
        #expect(canJustBefore == true)
        #expect(canExactly == false)
    }

    @Test("부여 시각이 현재보다 미래인 기록은 유효하지 않다")
    func canApplyColorTheme_whenGrantedAtIsFuture_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: 1)

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == false)
    }

    @Test("정책에서 사용권 게이트를 껐으면 무료 plan 의 기록 없는 유료 테마도 허용한다")
    func canApplyColorTheme_whenGateDisabled_isTrue() {
        // given
        let policy = AppPolicy(colorThemeLicense: .init(isEnabled: false, licenseDays: 7))
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("정책의 사용권 항목이 유효하면 주입한 기본값이 아니라 그 기간으로 판정한다")
    func canApplyColorTheme_whenBothPropertiesValid_usesItsDays() {
        // given
        let policy = AppPolicy(colorThemeLicense: .init(isEnabled: true, licenseDays: 14))
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -10, policy: policy)
        let canWithin = within.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)
        let past = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: policy)

        // when
        let canPast = past.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("enabled 가 없으면 enabled 만 기본값(켜짐)을 쓰고 기간은 정책의 값을 쓴다")
    func canApplyColorTheme_whenEnabledMissing_usesDefaultEnabledAndItsDays() {
        // given
        let policy = AppPolicy(colorThemeLicense: .init(isEnabled: nil, licenseDays: 3))
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -2, policy: policy)
        let canWithin = within.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)
        let past = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -4, policy: policy)

        // when
        let canPast = past.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("license_days 가 무효면 기간만 기본값을 쓰고 enabled 는 정책의 값을 쓴다")
    func canApplyColorTheme_whenDaysInvalid_usesDefaultDaysAndItsEnabled() {
        // given
        let enabledPolicy = AppPolicy(colorThemeLicense: .init(isEnabled: true, licenseDays: nil))
        let within = self.makeUsecase(
            plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: enabledPolicy
        )
        let canWithin = within.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)
        let disabledPolicy = AppPolicy(colorThemeLicense: .init(isEnabled: false, licenseDays: nil))
        let disabled = self.makeUsecase(plan: self.userPlan(.free), policy: disabledPolicy)

        // when
        let canWhenDisabled = disabled.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(canWithin == true)
        #expect(canWhenDisabled == true)
    }

    @Test("정책에 사용권 항목이 없으면 모든 속성을 주입한 기본값으로 판정한다")
    func canApplyColorTheme_whenItemMissing_usesInjectedDefault() {
        // given
        let policy = AppPolicy(featureSwitches: ["someFeature": .init(isEnabled: true)])
        let withoutRecord = self.makeUsecase(plan: self.userPlan(.free), policy: policy)
        let canWithoutRecord = withoutRecord.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: policy)

        // when
        let canWithin = within.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(canWithoutRecord == false)
        #expect(canWithin == true)
    }

    @Test("정책을 아직 못 받았으면 모든 속성을 주입한 기본값으로 판정한다")
    func canApplyColorTheme_whenNoPolicy_usesInjectedDefault() {
        // given
        let withoutRecord = self.makeUsecase(plan: self.userPlan(.free), policy: nil)
        let canWithoutRecord = withoutRecord.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: nil)
        let canWithin = within.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)
        let past = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -40, policy: nil)

        // when
        let canPast = past.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(canWithoutRecord == false)
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("정책도 기본값도 판단할 수 없으면 허용한다")
    func canApplyColorTheme_whenNeitherPolicyNorDefaultDecides_isTrue() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), policy: nil, defaultPolicy: AppPolicy()
        )

        // when
        let can = usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("유료에서 무료로 돌아오면 기록해 둔 부여 시각으로 판정한다")
    func canApplyColorTheme_afterPaidToFree_usesRecordedGrantTime() {
        // given
        let expiredGrant = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -30)
        let canWithExpired = expiredGrant.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)
        let validGrant = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -2)

        // when
        let canWithValid = validGrant.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(canWithExpired == false)
        #expect(canWithValid == true)
    }
}


// MARK: - 컬러 테마 보상 사용권 기록

extension PaidFeatureGateUsecaseImpleTests {

    @Test("보상을 반영하면 기존 기록을 지금 시각으로 덮어쓴다")
    func grantColorThemeLicense_overwritesRecordWithNow() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -30)

        // when
        usecase.grantColorThemeLicense(at: self.now)

        // then
        #expect(self.stubLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
        #expect(usecase.canApplyColorThemeWithoutAd(self.paidTheme, at: self.now) == true)
    }
}


// MARK: - 커스텀 위젯 스타일을 새로 쓸 수 있나

extension PaidFeatureGateUsecaseImpleTests {

    @Test("유료 plan 은 사용권이 없어도 커스텀을 쓸 수 있다", arguments: [
        BillingPlanId.standard, .lifetime
    ])
    func canCreateCustomWidgetStyle_whenPaid_isTrue(_ planId: BillingPlanId) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(planId))

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("plan 을 아직 못 받았으면 커스텀을 쓸 수 없다")
    func canCreateCustomWidgetStyle_whenPlanPending_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: nil)

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == false)
    }

    @Test("앱이 모르는 plan 이면 커스텀을 쓸 수 있다")
    func canCreateCustomWidgetStyle_whenPlanUnknown_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(nil))

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 에 사용권 기록이 없으면 커스텀을 쓸 수 없다")
    func canCreateCustomWidgetStyle_whenFreeAndNoLicense_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == false)
    }

    @Test("무료 plan 이라도 사용권이 유효하면 커스텀을 쓸 수 있다")
    func canCreateCustomWidgetStyle_whenFreeAndLicenseValid_isTrue() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -3
        )

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 의 사용권이 만료되면 커스텀을 쓸 수 없다")
    func canCreateCustomWidgetStyle_whenFreeAndLicenseExpired_isFalse() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -6
        )

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == false)
    }

    @Test("정책에서 위젯 사용권 게이트를 껐으면 무료 plan 의 기록 없는 커스텀도 허용한다")
    func canCreateCustomWidgetStyle_whenGateDisabled_isTrue() {
        // given
        let policy = AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: 5))
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 이라도 위젯 사용권 기간이 0 이하면 커스텀을 쓸 수 있다", arguments: [0, -1])
    func canCreateCustomWidgetStyle_whenFreeAndLicenseDaysNotPositive_isTrue(_ days: Int) {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free),
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: days))
        )

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("플랜을 못 받았어도 위젯 사용권 게이트가 꺼져 있으면 커스텀을 쓸 수 있다")
    func canCreateCustomWidgetStyle_whenPlanPendingAndGateDisabled_isTrue() {
        // given
        let disabled = self.makeUsecase(
            plan: nil,
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: 5))
        )
        let canWhenDisabled = disabled.canCreateCustomWidgetStyleWithoutAd(at: self.now)
        let zeroDays = self.makeUsecase(
            plan: nil,
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: 0))
        )

        // when
        let canWhenZeroDays = zeroDays.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(canWhenDisabled == true)
        #expect(canWhenZeroDays == true)
    }

    @Test("플랜도 위젯 정책도 판단할 수 없으면 커스텀 쓰기를 막지 않는다")
    func canCreateCustomWidgetStyle_whenPlanPendingAndPolicyUndecidable_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: nil, policy: nil, defaultPolicy: AppPolicy())

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("컬러 테마 게이트가 꺼져 있어도 위젯 판정은 위젯 정책을 따른다")
    func canCreateCustomWidgetStyle_whenColorThemeGateDisabled_usesWidgetPolicy() {
        // given
        let policy = AppPolicy(
            colorThemeLicense: .init(isEnabled: false, licenseDays: 7),
            widgetStyleLicense: .init(isEnabled: true, licenseDays: 5)
        )
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == false)
    }
}


// MARK: - 커스텀 위젯 스타일을 그릴 수 있나

extension PaidFeatureGateUsecaseImpleTests {

    @Test("유료 plan 은 사용권이 없어도 커스텀을 그린다", arguments: [
        BillingPlanId.standard, .lifetime
    ])
    func canRenderCustomWidgetStyle_whenPaid_isTrue(_ planId: BillingPlanId) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(planId))

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("plan 을 아직 못 받았으면 잠그지 않고 커스텀을 그린다")
    func canRenderCustomWidgetStyle_whenPlanPending_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: nil)

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("앱이 모르는 plan 이면 커스텀을 그린다")
    func canRenderCustomWidgetStyle_whenPlanUnknown_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(nil))

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 에 사용권 기록이 없으면 커스텀을 그리지 않는다")
    func canRenderCustomWidgetStyle_whenFreeAndNoLicense_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == false)
    }

    @Test("무료 plan 이라도 사용권이 유효하면 커스텀을 그린다")
    func canRenderCustomWidgetStyle_whenFreeAndLicenseValid_isTrue() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -3
        )

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 의 사용권이 만료되면 커스텀을 그리지 않는다")
    func canRenderCustomWidgetStyle_whenFreeAndLicenseExpired_isFalse() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -6
        )

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == false)
    }

    @Test("무료 plan 이라도 위젯 사용권 기간이 0 이하면 커스텀을 그린다", arguments: [0, -1])
    func canRenderCustomWidgetStyle_whenFreeAndLicenseDaysNotPositive_isTrue(_ days: Int) {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free),
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: days))
        )

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == true)
    }

    @Test("정책에서 위젯 사용권 게이트를 껐으면 무료 plan 의 기록 없는 커스텀도 그린다")
    func canRenderCustomWidgetStyle_whenGateDisabled_isTrue() {
        // given
        let policy = AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: 5))
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(can == true)
    }
}


// MARK: - 위젯 사용권의 기간·경계·정책 해석

extension PaidFeatureGateUsecaseImpleTests {

    @Test("위젯 사용권은 부여 시각부터 정확히 n×24시간이 지난 순간에 만료된다")
    func customWidgetStyleLicense_expiresExactlyAtLicenseDays() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: 0
        )
        let span = TimeInterval(self.widgetLicenseDays * 24 * 3600)
        let justBefore = self.now.addingTimeInterval(span - 1)
        let exactly = self.now.addingTimeInterval(span)

        // when
        let canJustBefore = usecase.canCreateCustomWidgetStyleWithoutAd(at: justBefore)
        let canExactly = usecase.canCreateCustomWidgetStyleWithoutAd(at: exactly)

        // then
        #expect(canJustBefore == true)
        #expect(canExactly == false)
    }

    @Test("부여 시각이 현재보다 미래인 위젯 사용권은 유효하지 않다")
    func customWidgetStyleLicense_whenGrantedAtIsFuture_isFalse() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: 1
        )

        // when
        let can = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(can == false)
    }

    @Test("위젯 정책의 기간이 유효하면 주입한 기본값이 아니라 그 기간으로 판정한다")
    func customWidgetStyleLicense_whenPolicyDaysValid_usesItsDays() {
        // given
        let policy = AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: 14))
        let within = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -10, policy: policy
        )
        let canWithin = within.canCreateCustomWidgetStyleWithoutAd(at: self.now)
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -18, policy: policy
        )

        // when
        let canPast = past.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("위젯 정책의 enabled 가 없으면 enabled 만 기본값(켜짐)을 쓰고 기간은 정책의 값을 쓴다")
    func customWidgetStyleLicense_whenEnabledMissing_usesDefaultEnabledAndItsDays() {
        // given
        let policy = AppPolicy(widgetStyleLicense: .init(isEnabled: nil, licenseDays: 3))
        let within = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -2, policy: policy
        )
        let canWithin = within.canCreateCustomWidgetStyleWithoutAd(at: self.now)
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -4, policy: policy
        )

        // when
        let canPast = past.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("위젯 정책의 기간이 없으면 기간만 기본값을 쓰고 enabled 는 정책의 값을 쓴다")
    func customWidgetStyleLicense_whenDaysMissing_usesDefaultDaysAndItsEnabled() {
        // given
        let enabledPolicy = AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: nil))
        let within = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -20, policy: enabledPolicy
        )
        let canWithin = within.canCreateCustomWidgetStyleWithoutAd(at: self.now)
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -25, policy: enabledPolicy
        )
        let canPast = past.canCreateCustomWidgetStyleWithoutAd(at: self.now)
        let disabledPolicy = AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: nil))
        let disabled = self.makeUsecase(plan: self.userPlan(.free), policy: disabledPolicy)

        // when
        let canWhenDisabled = disabled.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
        #expect(canWhenDisabled == true)
    }

    @Test("정책에 위젯 사용권 항목이 없으면 주입한 기본값으로 판정한다")
    func customWidgetStyleLicense_whenPolicyMissing_usesInjectedDefault() {
        // given
        let policy = AppPolicy(colorThemeLicense: .init(isEnabled: true, licenseDays: 7))
        let within = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -10, policy: policy
        )
        let canWithin = within.canCreateCustomWidgetStyleWithoutAd(at: self.now)
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -30, policy: policy
        )

        // when
        let canPast = past.canCreateCustomWidgetStyleWithoutAd(at: self.now)

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("위젯 정책도 기본값도 판단할 수 없으면 쓰기·렌더 둘 다 허용한다")
    func customWidgetStyleLicense_whenNeitherPolicyNorDefaultDecides_isTrue() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), policy: nil, defaultPolicy: AppPolicy()
        )

        // when
        let canCreate = usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now)
        let canRender = usecase.canRenderCustomWidgetStyle(at: self.now)

        // then
        #expect(canCreate == true)
        #expect(canRender == true)
    }
}


// MARK: - 위젯 커스텀 스타일 보상 사용권 기록

extension PaidFeatureGateUsecaseImpleTests {

    @Test("보상을 반영하면 위젯 사용권 기록을 지금 시각으로 덮어쓴다")
    func grantCustomWidgetStyleLicense_recordsGrantedAt() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -30
        )

        // when
        usecase.grantCustomWidgetStyleLicense(at: self.now)

        // then
        #expect(self.stubWidgetLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
        #expect(usecase.canCreateCustomWidgetStyleWithoutAd(at: self.now) == true)
    }

    @Test("위젯 보상 반영은 컬러 테마 사용권을 건드리지 않는다")
    func grantCustomWidgetStyleLicense_doesNotTouchColorThemeLicense() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        usecase.grantCustomWidgetStyleLicense(at: self.now)

        // then
        #expect(self.stubLicenseRepository.didUpdatedLicense == nil)
        #expect(self.stubWidgetLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
    }
}
