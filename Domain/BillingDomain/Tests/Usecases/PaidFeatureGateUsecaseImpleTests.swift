//
//  PaidFeatureGateUsecaseImpleTests.swift
//  BillingDomainTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
@testable import BillingDomain
@testable import BillingDomainInterface
@testable import SettingDomainInterface
@testable import SettingDomainTesting



final class PaidFeatureGateUsecaseImpleTests {

    private let now = Date(timeIntervalSince1970: 1_787_000_000)
    private let licenseDays = 7
    private let widgetLicenseDays = 5
    private let paidTheme: ColorSetKeys = .custom("paid-custom")
    private let newCustomTheme: ColorSetKeys = .custom("new-theme")

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
            planSource: StubBillingUserPlanSource(plan: plan),
            licenseRepository: self.stubLicenseRepository,
            widgetStyleLicenseRepository: self.stubWidgetLicenseRepository,
            policyRepository: StubAppPolicyRepository(policy: policy),
            defaultPolicy: defaultPolicy ?? self.injectedDefault
        )
    }

    private func passes(_ check: () throws -> Void) -> Bool {
        return self.blockedReason(check) == nil
    }

    private func blockedReason(_ check: () throws -> Void) -> PaidFeatureGateFailReason? {
        do {
            try check()
            return nil
        } catch let reason as PaidFeatureGateFailReason {
            return reason
        } catch {
            Issue.record(error)
            return nil
        }
    }
}


// MARK: - 컬러 테마를 광고 없이 쓸 수 있나

extension PaidFeatureGateUsecaseImpleTests {

    @Test("무료 테마는 무료 플랜에 사용권이 없어도 항상 허용한다", arguments: [
        ColorSetKeys.systemTheme, .defaultLight, .defaultDark
    ])
    func checkColorTheme_freeTheme_alwaysPasses(_ key: ColorSetKeys) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = self.passes { try usecase.check(key.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("앱이 기본 제공하는 테마는 무료 plan 에 사용권이 없어도 허용한다", arguments: [
        ColorSetKeys.appTheme(.tomato), .appTheme(.midnight), .appTheme(.sunset)
    ])
    func checkColorTheme_appTheme_whenFreeAndNoLicense_passes(_ key: ColorSetKeys) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = self.passes { try usecase.check(key.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("커스텀 테마는 무료 plan 에 사용권이 없으면 막는다")
    func checkColorTheme_customTheme_whenFreeAndNoLicense_blocks() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let reason = self.blockedReason { try usecase.check(.colorTheme(isCustom: true), at: self.now) }

        // then
        #expect(reason == .init(feature: .colorTheme(isCustom: true), licenseDays: 7))
    }

    @Test("plan 을 아직 못 받았으면 유료 테마도 허용한다")
    func checkColorTheme_paidTheme_whenPlanPending_passes() {
        // given
        let usecase = self.makeUsecase(plan: nil)

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("앱이 모르는 plan 이면 유료 테마도 허용한다")
    func checkColorTheme_paidTheme_whenPlanUnknown_passes() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(nil))

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("유료 plan 은 사용권이 없어도 유료 테마를 허용한다", arguments: [
        BillingPlanId.standard, .lifetime
    ])
    func checkColorTheme_paidTheme_whenPaid_passes(_ planId: BillingPlanId) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(planId))

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("무료 plan 에 사용권 기록이 없으면 유료 테마를 허용하지 않는다")
    func checkColorTheme_paidTheme_whenFreeAndNoLicense_blocks() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == false)
    }

    @Test("무료 plan 이라도 사용권이 유효하면 유료 테마를 허용한다")
    func checkColorTheme_paidTheme_whenFreeAndLicenseValid_passes() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -3)

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("무료 plan 의 사용권이 만료되면 유료 테마를 허용하지 않는다")
    func checkColorTheme_paidTheme_whenFreeAndLicenseExpired_blocks() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -8)

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == false)
    }

    @Test("사용권은 부여 시각부터 정확히 n×24시간이 지난 순간에 만료된다")
    func checkColorTheme_licenseBoundary_expiresExactlyAtLicenseDays() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: 0)
        let justBefore = self.now.addingTimeInterval(TimeInterval(self.licenseDays * 24 * 3600) - 1)
        let exactly = self.now.addingTimeInterval(TimeInterval(self.licenseDays * 24 * 3600))

        // when
        let canJustBefore = self.passes { try usecase.check(self.paidTheme.paidFeature, at: justBefore) }
        let canExactly = self.passes { try usecase.check(self.paidTheme.paidFeature, at: exactly) }

        // then
        #expect(canJustBefore == true)
        #expect(canExactly == false)
    }

    @Test("부여 시각이 현재보다 미래인 기록은 유효하지 않다")
    func checkColorTheme_whenGrantedAtIsFuture_blocks() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: 1)

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == false)
    }

    @Test("정책에서 사용권 게이트를 껐으면 무료 plan 의 기록 없는 유료 테마도 허용한다")
    func checkColorTheme_whenGateDisabled_passes() {
        // given
        let policy = AppPolicy(colorThemeLicense: .init(isEnabled: false, licenseDays: 7))
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("정책의 사용권 항목이 유효하면 주입한 기본값이 아니라 그 기간으로 판정한다")
    func checkColorTheme_whenBothPropertiesValid_usesItsDays() {
        // given
        let policy = AppPolicy(colorThemeLicense: .init(isEnabled: true, licenseDays: 14))
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -10, policy: policy)
        let canWithin = self.passes { try within.check(self.paidTheme.paidFeature, at: self.now) }
        let past = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: policy)

        // when
        let canPast = self.passes { try past.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("enabled 가 없으면 enabled 만 기본값(켜짐)을 쓰고 기간은 정책의 값을 쓴다")
    func checkColorTheme_whenEnabledMissing_usesDefaultEnabledAndItsDays() {
        // given
        let policy = AppPolicy(colorThemeLicense: .init(isEnabled: nil, licenseDays: 3))
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -2, policy: policy)
        let canWithin = self.passes { try within.check(self.paidTheme.paidFeature, at: self.now) }
        let past = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -4, policy: policy)

        // when
        let canPast = self.passes { try past.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("license_days 가 무효면 기간만 기본값을 쓰고 enabled 는 정책의 값을 쓴다")
    func checkColorTheme_whenDaysInvalid_usesDefaultDaysAndItsEnabled() {
        // given
        let enabledPolicy = AppPolicy(colorThemeLicense: .init(isEnabled: true, licenseDays: nil))
        let within = self.makeUsecase(
            plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: enabledPolicy
        )
        let canWithin = self.passes { try within.check(self.paidTheme.paidFeature, at: self.now) }
        let disabledPolicy = AppPolicy(colorThemeLicense: .init(isEnabled: false, licenseDays: nil))
        let disabled = self.makeUsecase(plan: self.userPlan(.free), policy: disabledPolicy)

        // when
        let canWhenDisabled = self.passes { try disabled.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(canWithin == true)
        #expect(canWhenDisabled == true)
    }

    @Test("정책에 사용권 항목이 없으면 모든 속성을 주입한 기본값으로 판정한다")
    func checkColorTheme_whenItemMissing_usesInjectedDefault() {
        // given
        let policy = AppPolicy(featureSwitches: ["someFeature": .init(isEnabled: true)])
        let withoutRecord = self.makeUsecase(plan: self.userPlan(.free), policy: policy)
        let canWithoutRecord = self.passes { try withoutRecord.check(self.paidTheme.paidFeature, at: self.now) }
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: policy)

        // when
        let canWithin = self.passes { try within.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(canWithoutRecord == false)
        #expect(canWithin == true)
    }

    @Test("정책을 아직 못 받았으면 모든 속성을 주입한 기본값으로 판정한다")
    func checkColorTheme_whenNoPolicy_usesInjectedDefault() {
        // given
        let withoutRecord = self.makeUsecase(plan: self.userPlan(.free), policy: nil)
        let canWithoutRecord = self.passes { try withoutRecord.check(self.paidTheme.paidFeature, at: self.now) }
        let within = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -20, policy: nil)
        let canWithin = self.passes { try within.check(self.paidTheme.paidFeature, at: self.now) }
        let past = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -40, policy: nil)

        // when
        let canPast = self.passes { try past.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(canWithoutRecord == false)
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("정책도 기본값도 판단할 수 없으면 허용한다")
    func checkColorTheme_whenNeitherPolicyNorDefaultDecides_passes() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), policy: nil, defaultPolicy: AppPolicy()
        )

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("유료에서 무료로 돌아오면 기록해 둔 부여 시각으로 판정한다")
    func checkColorTheme_afterPaidToFree_usesRecordedGrantTime() {
        // given
        let expiredGrant = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -30)
        let canWithExpired = self.passes { try expiredGrant.check(self.paidTheme.paidFeature, at: self.now) }
        let validGrant = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -2)

        // when
        let canWithValid = self.passes { try validGrant.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(canWithExpired == false)
        #expect(canWithValid == true)
    }
    @Test("무료 plan 이라도 사용권 기간이 0 이하면 유료 테마를 허용한다", arguments: [0, -1])
    func checkColorTheme_whenFreeAndLicenseDaysNotPositive_passes(_ days: Int) {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free),
            policy: AppPolicy(colorThemeLicense: .init(isEnabled: true, licenseDays: days))
        )

        // when
        let can = self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) }

        // then
        #expect(can == true)
    }
}


// MARK: - 컬러 테마 보상 사용권 기록

extension PaidFeatureGateUsecaseImpleTests {

    @Test("보상을 반영하면 기존 기록을 지금 시각으로 덮어쓴다")
    func grantLicense_colorTheme_overwritesRecordWithNow() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -30)

        // when
        usecase.grantLicense(for: self.paidTheme.paidFeature, at: self.now)

        // then
        #expect(self.stubLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
        #expect(self.passes { try usecase.check(self.paidTheme.paidFeature, at: self.now) } == true)
    }
}


// MARK: - 컬러 테마를 막을 때 싣는 사용권 기간

extension PaidFeatureGateUsecaseImpleTests {

    @Test("막을 때 싣는 사용권 기간은 정책에서 해석한 값이고, 해석할 수 없으면 막지 않는다")
    func checkColorTheme_blockedReasonCarriesResolvedDays() {
        // given
        let fromPolicy = self.makeUsecase(
            plan: self.userPlan(.free),
            policy: AppPolicy(colorThemeLicense: .init(isEnabled: true, licenseDays: 14))
        )
        let fromDefault = self.makeUsecase(plan: self.userPlan(.free), policy: nil)
        let undecidable = self.makeUsecase(
            plan: self.userPlan(.free), policy: nil, defaultPolicy: AppPolicy()
        )

        // when
        let reasons = [fromPolicy, fromDefault, undecidable].map { usecase in
            self.blockedReason { try usecase.check(self.paidTheme.paidFeature, at: self.now) }
        }

        // then
        #expect(reasons == [
            .init(feature: .colorTheme(isCustom: true), licenseDays: 14),
            .init(feature: .colorTheme(isCustom: true), licenseDays: 30),
            nil
        ])
    }
}


// MARK: - 커스텀 위젯 스타일을 새로 쓸 수 있나

extension PaidFeatureGateUsecaseImpleTests {

    @Test("유료 plan 은 사용권이 없어도 커스텀을 쓸 수 있다", arguments: [
        BillingPlanId.standard, .lifetime
    ])
    func checkCustomizeWidget_whenPaid_passes(_ planId: BillingPlanId) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(planId))

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("plan 을 아직 못 받았으면 커스텀을 쓸 수 없다")
    func checkCustomizeWidget_whenPlanPending_blocks() {
        // given
        let usecase = self.makeUsecase(plan: nil)

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == false)
    }

    @Test("앱이 모르는 plan 이면 커스텀을 쓸 수 있다")
    func checkCustomizeWidget_whenPlanUnknown_passes() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(nil))

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("무료 plan 에 사용권 기록이 없으면 커스텀을 쓸 수 없다")
    func checkCustomizeWidget_whenFreeAndNoLicense_blocks() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == false)
    }

    @Test("무료 plan 이라도 사용권이 유효하면 커스텀을 쓸 수 있다")
    func checkCustomizeWidget_whenFreeAndLicenseValid_passes() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -3
        )

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("무료 plan 의 사용권이 만료되면 커스텀을 쓸 수 없다")
    func checkCustomizeWidget_whenFreeAndLicenseExpired_blocks() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -6
        )

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == false)
    }

    @Test("정책에서 위젯 사용권 게이트를 껐으면 무료 plan 의 기록 없는 커스텀도 허용한다")
    func checkCustomizeWidget_whenGateDisabled_passes() {
        // given
        let policy = AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: 5))
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("무료 plan 이라도 위젯 사용권 기간이 0 이하면 커스텀을 쓸 수 있다", arguments: [0, -1])
    func checkCustomizeWidget_whenFreeAndLicenseDaysNotPositive_passes(_ days: Int) {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free),
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: days))
        )

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("플랜을 못 받았어도 위젯 사용권 게이트가 꺼져 있으면 커스텀을 쓸 수 있다")
    func checkCustomizeWidget_whenPlanPendingAndGateDisabled_passes() {
        // given
        let disabled = self.makeUsecase(
            plan: nil,
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: 5))
        )
        let canWhenDisabled = self.passes { try disabled.check(.customizeWidget, at: self.now) }
        let zeroDays = self.makeUsecase(
            plan: nil,
            policy: AppPolicy(widgetStyleLicense: .init(isEnabled: true, licenseDays: 0))
        )

        // when
        let canWhenZeroDays = self.passes { try zeroDays.check(.customizeWidget, at: self.now) }

        // then
        #expect(canWhenDisabled == true)
        #expect(canWhenZeroDays == true)
    }

    @Test("플랜도 위젯 정책도 판단할 수 없으면 커스텀 쓰기를 막지 않는다")
    func checkCustomizeWidget_whenPlanPendingAndPolicyUndecidable_passes() {
        // given
        let usecase = self.makeUsecase(plan: nil, policy: nil, defaultPolicy: AppPolicy())

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == true)
    }

    @Test("컬러 테마 게이트가 꺼져 있어도 위젯 판정은 위젯 정책을 따른다")
    func checkCustomizeWidget_whenColorThemeGateDisabled_usesWidgetPolicy() {
        // given
        let policy = AppPolicy(
            colorThemeLicense: .init(isEnabled: false, licenseDays: 7),
            widgetStyleLicense: .init(isEnabled: true, licenseDays: 5)
        )
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == false)
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
        let canJustBefore = self.passes { try usecase.check(.customizeWidget, at: justBefore) }
        let canExactly = self.passes { try usecase.check(.customizeWidget, at: exactly) }

        // then
        #expect(canJustBefore == true)
        #expect(canExactly == false)
    }

    @Test("부여 시각이 현재보다 미래인 위젯 사용권은 유효하지 않다")
    func customWidgetStyleLicense_whenGrantedAtIsFuture_blocks() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: 1
        )

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

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
        let canWithin = self.passes { try within.check(.customizeWidget, at: self.now) }
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -18, policy: policy
        )

        // when
        let canPast = self.passes { try past.check(.customizeWidget, at: self.now) }

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
        let canWithin = self.passes { try within.check(.customizeWidget, at: self.now) }
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -4, policy: policy
        )

        // when
        let canPast = self.passes { try past.check(.customizeWidget, at: self.now) }

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
        let canWithin = self.passes { try within.check(.customizeWidget, at: self.now) }
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -25, policy: enabledPolicy
        )
        let canPast = self.passes { try past.check(.customizeWidget, at: self.now) }
        let disabledPolicy = AppPolicy(widgetStyleLicense: .init(isEnabled: false, licenseDays: nil))
        let disabled = self.makeUsecase(plan: self.userPlan(.free), policy: disabledPolicy)

        // when
        let canWhenDisabled = self.passes { try disabled.check(.customizeWidget, at: self.now) }

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
        let canWithin = self.passes { try within.check(.customizeWidget, at: self.now) }
        let past = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -30, policy: policy
        )

        // when
        let canPast = self.passes { try past.check(.customizeWidget, at: self.now) }

        // then
        #expect(canWithin == true)
        #expect(canPast == false)
    }

    @Test("위젯 정책도 기본값도 판단할 수 없으면 꾸미기를 허용한다")
    func customWidgetStyleLicense_whenNeitherPolicyNorDefaultDecides_passes() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), policy: nil, defaultPolicy: AppPolicy()
        )

        // when
        let can = self.passes { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(can == true)
    }
}


// MARK: - 위젯 커스텀 스타일 보상 사용권 기록

extension PaidFeatureGateUsecaseImpleTests {

    @Test("보상을 반영하면 위젯 사용권 기록을 지금 시각으로 덮어쓴다")
    func grantLicense_customizeWidget_recordsGrantedAt() {
        // given
        let usecase = self.makeUsecase(
            plan: self.userPlan(.free), widgetGrantedDaysFromNow: -30
        )

        // when
        usecase.grantLicense(for: .customizeWidget, at: self.now)

        // then
        #expect(self.stubWidgetLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
        #expect(self.passes { try usecase.check(.customizeWidget, at: self.now) } == true)
    }

    @Test("위젯 보상 반영은 컬러 테마 사용권을 건드리지 않는다")
    func grantLicense_customizeWidget_doesNotTouchColorThemeLicense() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        usecase.grantLicense(for: .customizeWidget, at: self.now)

        // then
        #expect(self.stubLicenseRepository.didUpdatedLicense == nil)
        #expect(self.stubWidgetLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
    }
}


// MARK: - 위젯을 막을 때 싣는 사용권 기간

extension PaidFeatureGateUsecaseImpleTests {

    @Test("위젯을 막을 때 싣는 사용권 기간은 위젯 정책에서 해석한 값이고, 해석할 수 없으면 막지 않는다")
    func checkCustomizeWidget_blockedReasonCarriesResolvedDays() {
        // given
        let fromPolicy = self.makeUsecase(
            plan: self.userPlan(.free),
            policy: AppPolicy(
                colorThemeLicense: .init(isEnabled: true, licenseDays: 14),
                widgetStyleLicense: .init(isEnabled: true, licenseDays: 9)
            )
        )
        let fromDefault = self.makeUsecase(plan: self.userPlan(.free), policy: nil)
        let undecidable = self.makeUsecase(
            plan: self.userPlan(.free), policy: nil, defaultPolicy: AppPolicy()
        )

        // when
        let reasons = [fromPolicy, fromDefault, undecidable].map { usecase in
            self.blockedReason { try usecase.check(.customizeWidget, at: self.now) }
        }

        // then
        #expect(reasons == [
            .init(feature: .customizeWidget, licenseDays: 9),
            .init(feature: .customizeWidget, licenseDays: 21),
            nil
        ])
    }
}


// MARK: - 컬러 테마 생성

extension PaidFeatureGateUsecaseImpleTests {

    @Test("무료 plan 에 사용권이 없으면 새 커스텀 테마 키를 막고 그 키를 사유에 싣는다")
    func checkNewColorTheme_whenFreeWithoutLicense_throwsCreateReason() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let reason = self.blockedReason { try usecase.check(self.newCustomTheme.paidFeature, at: self.now) }

        // then
        #expect(reason == .init(feature: .colorTheme(isCustom: true), licenseDays: 7))
    }

    @Test("유료 plan 이거나 사용권이 유효하면 새 테마 만들기를 막지 않는다")
    func checkNewColorTheme_whenPaidOrLicensed_passes() {
        // given
        let paid = self.makeUsecase(plan: self.userPlan(.standard))
        let licensed = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -1)

        // when
        let results = [paid, licensed].map { usecase in
            self.passes { try usecase.check(self.newCustomTheme.paidFeature, at: self.now) }
        }

        // then
        #expect(results == [true, true])
    }

    @Test("새 테마 만들기 사용권을 받으면 컬러 테마 사용권에 기록한다")
    func grantLicense_newColorTheme_recordsColorThemeLicense() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        usecase.grantLicense(for: self.newCustomTheme.paidFeature, at: self.now)

        // then
        #expect(self.stubLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
        #expect(self.stubWidgetLicenseRepository.didUpdatedLicense == nil)
    }
}


// MARK: - 플랜을 모를 때 위젯 사용권

extension PaidFeatureGateUsecaseImpleTests {

    @Test("플랜을 아직 모르더라도 광고로 받은 위젯 사용권이 유효하면 커스텀을 쓸 수 있다")
    func checkCustomizeWidget_whenPlanPendingAndLicenseValid_passes() {
        // given
        let usecase = self.makeUsecase(plan: nil, widgetGrantedDaysFromNow: -1)

        // when
        let reason = self.blockedReason { try usecase.check(.customizeWidget, at: self.now) }

        // then
        #expect(reason == nil)
    }
}
