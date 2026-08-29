//
//  AdExposureUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Combine
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


final class AdExposureUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_787_000_000)

    private func date(daysFromNow days: Int) -> Date {
        return self.now.addingTimeInterval(TimeInterval(days) * 24 * 3600)
    }

    private func userPlan(_ planId: BillingPlanId) -> BillingUserPlan {
        return BillingUserPlan() |> \.planId .~ planId
    }

    private func coldLaunchHistory(
        count: Int, firstLaunchDaysAgo: Int, isFirstLaunchOfToday: Bool
    ) -> AppColdLaunchHistory {
        var history = AppColdLaunchHistory()
        history.firstLaunchDate = self.date(daysFromNow: -firstLaunchDaysAgo)
        history.count = count
        history.lastLaunchDate = self.now
        history.previousLaunchDate = isFirstLaunchOfToday
            ? self.date(daysFromNow: -1)
            : self.now.addingTimeInterval(-60)
        return history
    }

    private func makeUsecase(
        isAdStarted: Bool = true,
        userPlan: BillingUserPlan? = nil,
        exposureRecords: [FullScreenAdExposureRecord] = [],
        coldLaunchHistory: AppColdLaunchHistory = .init()
    ) -> AdExposureUsecaseImple {
        self.spyAdRepository = SpyAdRepository(records: exposureRecords)
        self.stubBillingUsecase = StubBillingUsecase(stubUserPlan: userPlan)
        self.stubAdAvailability = StubMobileAdAvailability(isStarted: isAdStarted)
        return AdExposureUsecaseImple(
            adAvailability: self.stubAdAvailability,
            billingUsecase: self.stubBillingUsecase,
            adRepository: self.spyAdRepository,
            coldLaunchHistoryRepository: StubAppColdLaunchHistoryRepository(history: coldLaunchHistory),
            calendar: self.calendar
        )
    }

    private var spyAdRepository: SpyAdRepository!
    private var stubBillingUsecase: StubBillingUsecase!
    private var stubAdAvailability: StubMobileAdAvailability!
}


// MARK: - 배너 노출 허용 여부

extension AdExposureUsecaseImpleTests {

    @Test("광고 SDK 가 시작되지 않았으면 배너를 허용하지 않는다")
    func usecase_whenAdNotStarted_bannerIsNotAllowed() async throws {
        // given
        let expect = expectConfirm("배너 불허")
        let usecase = self.makeUsecase(isAdStarted: false, userPlan: self.userPlan(.free))

        // when
        let isAllowed = try await self.firstOutput(expect, for: usecase.isBannerAdAllowed)

        // then
        #expect(isAllowed == false)
    }

    @Test("SDK 가 시작됐고 free 플랜이면 배너를 허용한다")
    func usecase_whenAdStartedAndFreePlan_bannerIsAllowed() async throws {
        // given
        let expect = expectConfirm("배너 허용")
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        let isAllowed = try await self.firstOutput(expect, for: usecase.isBannerAdAllowed)

        // then
        #expect(isAllowed == true)
    }

    @Test("SDK 가 시작됐어도 유료 플랜이면 배너를 허용하지 않는다")
    func usecase_whenAdStartedAndPaidPlan_bannerIsNotAllowed() async throws {
        // given
        let expect = expectConfirm("배너 불허")
        let usecase = self.makeUsecase(userPlan: self.userPlan(.standard))

        // when
        let isAllowed = try await self.firstOutput(expect, for: usecase.isBannerAdAllowed)

        // then
        #expect(isAllowed == false)
    }

    @Test("세션 중 유료로 전환되면 배너가 내려간다")
    func usecase_whenPlanChangesToPaidDuringSession_bannerBecomesNotAllowed() async throws {
        // given
        let expect = expectConfirm("허용 → 불허")
        expect.count = 2
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        let isAlloweds = try await self.outputs(expect, for: usecase.isBannerAdAllowed) {
            self.stubBillingUsecase.currentUserPlanSubject.send(self.userPlan(.lifetime))
        }

        // then
        #expect(isAlloweds == [true, false])
    }

    @Test("유저 플랜이 한 번도 방출되지 않으면 배너를 허용하지 않는다")
    func usecase_whenUserPlanNeverEmits_bannerIsNotAllowed() async throws {
        // given
        let expect = expectConfirm("무방출")
        expect.count = 0
        let usecase = self.makeUsecase(userPlan: nil)

        // when
        let isAlloweds = try await self.outputs(expect, for: usecase.isBannerAdAllowed)

        // then
        #expect(isAlloweds.isEmpty == true)
    }
}


// MARK: - 앱 실행 직후 추가 조건

extension AdExposureUsecaseImpleTests {

    @Test("콜드 런치 이력이 없으면 앱 실행 직후 전면 광고를 허용하지 않는다")
    func usecase_fromAppLaunch_whenNoColdLaunchHistory_isNotAllowed() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: true, at: self.now
        )

        // then
        #expect(canExpose == false)
    }

    @Test("같은 날 두 번째 콜드 런치면 앱 실행 직후 전면 광고를 허용하지 않는다")
    func usecase_fromAppLaunch_whenSecondColdLaunchOfSameDay_isNotAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.free),
            coldLaunchHistory: self.coldLaunchHistory(
                count: 20, firstLaunchDaysAgo: 30, isFirstLaunchOfToday: false
            )
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: true, at: self.now
        )

        // then
        #expect(canExpose == false)
    }

    @Test("첫 실행일로부터 7일이 안 지났으면 앱 실행 직후 전면 광고를 허용하지 않는다")
    func usecase_fromAppLaunch_whenElapsedDaysFromFirstLaunchIsUnderSeven_isNotAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.free),
            coldLaunchHistory: self.coldLaunchHistory(
                count: 20, firstLaunchDaysAgo: 6, isFirstLaunchOfToday: true
            )
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: true, at: self.now
        )

        // then
        #expect(canExpose == false)
    }

    @Test("누적 콜드 런치가 10회 미만이면 앱 실행 직후 전면 광고를 허용하지 않는다")
    func usecase_fromAppLaunch_whenColdLaunchCountIsUnderTen_isNotAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.free),
            coldLaunchHistory: self.coldLaunchHistory(
                count: 9, firstLaunchDaysAgo: 30, isFirstLaunchOfToday: true
            )
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: true, at: self.now
        )

        // then
        #expect(canExpose == false)
    }

    @Test("조건을 다 만족해도 유료 플랜이면 전면 광고를 허용하지 않는다")
    func usecase_fromAppLaunch_whenPaidPlan_isNotAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.standard),
            coldLaunchHistory: self.coldLaunchHistory(
                count: 20, firstLaunchDaysAgo: 30, isFirstLaunchOfToday: true
            )
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: true, at: self.now
        )

        // then
        #expect(canExpose == false)
    }

    @Test("조건을 전부 만족하면 앱 실행 직후 전면 광고를 허용한다")
    func usecase_fromAppLaunch_whenAllConditionsAreMet_isAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.free),
            coldLaunchHistory: self.coldLaunchHistory(
                count: 10, firstLaunchDaysAgo: 7, isFirstLaunchOfToday: true
            )
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: true, at: self.now
        )

        // then
        #expect(canExpose == true)
    }

    @Test("앱 실행 직후가 아니면 콜드 런치 조건을 보지 않는다")
    func usecase_notFromAppLaunch_whenColdLaunchConditionsAreNotMet_isStillAllowed() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: false, at: self.now
        )

        // then
        #expect(canExpose == true)
    }
}


// MARK: - scope 별 일 1회 상한

extension AdExposureUsecaseImpleTests {

    @Test("application scope 로 오늘 노출했으면 같은 날 다시 허용하지 않는다")
    func usecase_afterApplicationScopeExposed_applicationScopeIsNotAllowedInSameDay() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        usecase.recordFullScreenAdExposed(scope: .application, at: self.now)
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: false, at: self.now.addingTimeInterval(3600)
        )

        // then
        #expect(canExpose == false)
    }

    @Test("application scope 로 노출했어도 service scope 는 같은 날 허용한다")
    func usecase_afterApplicationScopeExposed_serviceScopeIsAllowedInSameDay() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        usecase.recordFullScreenAdExposed(scope: .application, at: self.now)
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .service(identifier: "eventShare"), isFromAppLaunch: false, at: self.now
        )

        // then
        #expect(canExpose == true)
    }

    @Test("service scope 로 오늘 노출했으면 같은 scope 는 같은 날 허용하지 않는다")
    func usecase_afterServiceScopeExposed_sameServiceScopeIsNotAllowedInSameDay() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        usecase.recordFullScreenAdExposed(scope: .service(identifier: "eventShare"), at: self.now)
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .service(identifier: "eventShare"), isFromAppLaunch: false, at: self.now
        )

        // then
        #expect(canExpose == false)
    }

    @Test("identifier 가 다른 service scope 는 독립적으로 허용한다")
    func usecase_afterServiceScopeExposed_differentServiceScopeIsAllowed() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        usecase.recordFullScreenAdExposed(scope: .service(identifier: "eventShare"), at: self.now)
        let canExpose = usecase.canExposeFullScreenAd(
            scope: .service(identifier: "other"), isFromAppLaunch: false, at: self.now
        )

        // then
        #expect(canExpose == true)
    }

    @Test("날짜가 바뀌면 모든 scope 를 다시 허용한다")
    func usecase_afterExposed_allScopesAreAllowedInNextDay() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        usecase.recordFullScreenAdExposed(scope: .application, at: self.now)
        usecase.recordFullScreenAdExposed(scope: .service(identifier: "eventShare"), at: self.now)
        let tomorrow = self.date(daysFromNow: 1)
        let canExposeApplication = usecase.canExposeFullScreenAd(
            scope: .application, isFromAppLaunch: false, at: tomorrow
        )
        let canExposeService = usecase.canExposeFullScreenAd(
            scope: .service(identifier: "eventShare"), isFromAppLaunch: false, at: tomorrow
        )

        // then
        #expect(canExposeApplication == true)
        #expect(canExposeService == true)
    }

    @Test("같은 scope 를 다시 기록하면 그 scope 의 레코드만 갱신한다")
    func usecase_recordFullScreenAdExposed_replaceRecordOfSameScope() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        usecase.recordFullScreenAdExposed(scope: .application, at: self.now)
        usecase.recordFullScreenAdExposed(scope: .application, at: self.date(daysFromNow: 1))

        // then
        #expect(self.spyAdRepository.didUpdatedExposureRecords.map { $0.lastExposeDate }
                == [self.now, self.date(daysFromNow: 1)])
        #expect(self.spyAdRepository.loadFullScreenAdExposureRecords()
                == [.init(scope: .application, lastExposeDate: self.date(daysFromNow: 1))])
    }
}
