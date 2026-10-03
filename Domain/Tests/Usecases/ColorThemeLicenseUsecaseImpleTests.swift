//
//  ColorThemeLicenseUsecaseImpleTests.swift
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


final class ColorThemeLicenseUsecaseImpleTests {

    private let now = Date(timeIntervalSince1970: 1_787_000_000)
    private let licenseDays = 7
    private let paidTheme: ColorSetKeys = .appTheme(.tomato)

    private var stubLicenseRepository: StubColorThemeLicenseRepository!

    private func date(daysFromNow days: Double) -> Date {
        return self.now.addingTimeInterval(days * 24 * 3600)
    }

    private func userPlan(_ planId: BillingPlanId?) -> BillingUserPlan {
        return BillingUserPlan() |> \.planId .~ planId
    }

    private func makeUsecase(
        plan: BillingUserPlan?,
        grantedDaysFromNow: Double? = nil,
        policy: AppPolicy? = AppPolicy(colorThemeLicense: .init(licenseDays: 7))
    ) -> ColorThemeLicenseUsecaseImple {
        self.stubLicenseRepository = StubColorThemeLicenseRepository(
            license: grantedDaysFromNow.map { .init(grantedAt: self.date(daysFromNow: $0)) }
        )
        return ColorThemeLicenseUsecaseImple(
            billingUsecase: StubBillingUsecase(stubUserPlan: plan),
            licenseRepository: self.stubLicenseRepository,
            policyRepository: StubAppPolicyRepository(policy: policy)
        )
    }
}


// MARK: - 광고 없이 적용 가능한가

extension ColorThemeLicenseUsecaseImpleTests {

    @Test("무료 테마는 무료 플랜에 사용권이 없어도 항상 허용한다", arguments: [
        ColorSetKeys.systemTheme, .defaultLight, .defaultDark
    ])
    func canApply_freeTheme_alwaysTrue(_ key: ColorSetKeys) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = usecase.canApplyWithoutAd(key, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("plan 을 아직 못 받았으면 유료 테마도 허용한다")
    func canApply_paidTheme_whenPlanPending_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: nil)

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("앱이 모르는 plan 이면 유료 테마도 허용한다")
    func canApply_paidTheme_whenPlanUnknown_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(nil))

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("유료 plan 은 사용권이 없어도 유료 테마를 허용한다", arguments: [
        BillingPlanId.standard, .lifetime
    ])
    func canApply_paidTheme_whenPaid_isTrue(_ planId: BillingPlanId) {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(planId))

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 에 사용권 기록이 없으면 유료 테마를 허용하지 않는다")
    func canApply_paidTheme_whenFreeAndNoLicense_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free))

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == false)
    }

    @Test("무료 plan 이라도 사용권이 유효하면 유료 테마를 허용한다")
    func canApply_paidTheme_whenFreeAndLicenseValid_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -3)

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("무료 plan 의 사용권이 만료되면 유료 테마를 허용하지 않는다")
    func canApply_paidTheme_whenFreeAndLicenseExpired_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -8)

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == false)
    }

    @Test("사용권은 부여 시각부터 정확히 n×24시간이 지난 순간에 만료된다")
    func canApply_licenseBoundary_expiresExactlyAtLicenseDays() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: 0)
        let justBefore = self.now.addingTimeInterval(TimeInterval(self.licenseDays * 24 * 3600) - 1)
        let exactly = self.now.addingTimeInterval(TimeInterval(self.licenseDays * 24 * 3600))

        // when
        let canJustBefore = usecase.canApplyWithoutAd(self.paidTheme, at: justBefore)
        let canExactly = usecase.canApplyWithoutAd(self.paidTheme, at: exactly)

        // then
        #expect(canJustBefore == true)
        #expect(canExactly == false)
    }

    @Test("부여 시각이 현재보다 미래인 기록은 유효하지 않다")
    func canApply_whenGrantedAtIsFuture_isFalse() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: 1)

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == false)
    }

    @Test("정책을 아직 못 읽었으면 무료 plan 의 만료된 유료 테마도 허용한다")
    func canApply_whenNoPolicy_isTrue() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: nil)

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("정책에 사용권 항목이 없으면 무료 plan 의 만료된 유료 테마도 허용한다")
    func canApply_whenPolicyHasNoColorThemeLicense_isTrue() {
        // given
        let policy = AppPolicy(featureSwitches: ["someFeature": .init(isEnabled: true)])
        let usecase = self.makeUsecase(plan: self.userPlan(.free), policy: policy)

        // when
        let can = usecase.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(can == true)
    }

    @Test("유료에서 무료로 돌아오면 기록해 둔 부여 시각으로 판정한다")
    func canApply_afterPaidToFree_usesRecordedGrantTime() {
        // given
        let expiredGrant = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -30)
        let canWithExpired = expiredGrant.canApplyWithoutAd(self.paidTheme, at: self.now)
        let validGrant = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -2)

        // when
        let canWithValid = validGrant.canApplyWithoutAd(self.paidTheme, at: self.now)

        // then
        #expect(canWithExpired == false)
        #expect(canWithValid == true)
    }
}


// MARK: - 보상 반영

extension ColorThemeLicenseUsecaseImpleTests {

    @Test("보상을 반영하면 기존 기록을 지금 시각으로 덮어쓴다")
    func grantLicense_overwritesRecordWithNow() {
        // given
        let usecase = self.makeUsecase(plan: self.userPlan(.free), grantedDaysFromNow: -30)

        // when
        usecase.grantLicense(at: self.now)

        // then
        #expect(self.stubLicenseRepository.didUpdatedLicense == .init(grantedAt: self.now))
        #expect(usecase.canApplyWithoutAd(self.paidTheme, at: self.now) == true)
    }
}
