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
import CombineSchedulers
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

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

    private var installedBeforeToday: AppColdLaunchHistory {
        return AppColdLaunchHistory() |> \.firstLaunchDate .~ self.date(daysFromNow: -1)
    }

    private func exposureRecord(
        secondsAgo: TimeInterval, countOfDay: Int
    ) -> FullScreenAdExposureRecord {
        return .init(
            lastExposeDate: self.now.addingTimeInterval(-secondsAgo), countOfDay: countOfDay
        )
    }

    private func makeUsecase(
        isAdStarted: Bool = true,
        userPlan: BillingUserPlan? = nil,
        exposureRecord: FullScreenAdExposureRecord? = nil,
        eventSavedCount: Int = 0,
        coldLaunchHistory: AppColdLaunchHistory = .init(),
        hasAnyEvent: Bool = false,
        shouldFailEventExistenceFetch: Bool = false,
        hasShownTrackingGuide: Bool = false,
        isTrackingAuthorizationDetermined: Bool = false,
        remotePolicy: AppPolicy? = nil,
        randomUnits: [Double] = [],
        scheduler: AnySchedulerOf<DispatchQueue> = .main
    ) -> AdExposureUsecaseImple {
        self.spyAdRepository = SpyAdRepository(
            record: exposureRecord,
            eventSavedCount: eventSavedCount,
            hasShownTrackingGuide: hasShownTrackingGuide
        )
        self.stubUserEventExistenceRepository = StubUserEventExistenceRepository(
            hasAnyEvent: hasAnyEvent, shouldFailFetch: shouldFailEventExistenceFetch
        )
        self.stubBillingUsecase = StubBillingUsecase(stubUserPlan: userPlan)
        self.stubAdAvailability = StubMobileAdAvailability(
            isStarted: isAdStarted,
            isTrackingAuthorizationDetermined: isTrackingAuthorizationDetermined
        )
        return AdExposureUsecaseImple(
            adAvailability: self.stubAdAvailability,
            billingUsecase: self.stubBillingUsecase,
            adRepository: self.spyAdRepository,
            coldLaunchHistoryRepository: StubAppColdLaunchHistoryRepository(history: coldLaunchHistory),
            userEventExistenceRepository: self.stubUserEventExistenceRepository,
            policyRepository: StubAppPolicyRepository(policy: remotePolicy),
            defaultPolicy: AppPolicy(
                mainBannerExposure: .init(
                    exposurePercentage: 75, minDelaySeconds: 60, maxDelaySeconds: 300
                )
            ),
            calendar: self.calendar,
            scheduler: scheduler,
            randomUnit: StubRandomUnits(randomUnits).next
        )
    }

    private var spyAdRepository: SpyAdRepository!
    private var stubUserEventExistenceRepository: StubUserEventExistenceRepository!
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


// MARK: - 메인 배너 노출 허용 여부

extension AdExposureUsecaseImpleTests {

    private func makeUsecaseForMainBanner(
        userPlan: BillingPlanId = .free,
        coldLaunchHistory: AppColdLaunchHistory? = nil,
        remotePolicy: AppPolicy? = nil,
        randomUnits: [Double],
        scheduler: TestSchedulerOf<DispatchQueue>
    ) -> AdExposureUsecaseImple {
        return self.makeUsecase(
            userPlan: self.userPlan(userPlan),
            coldLaunchHistory: coldLaunchHistory ?? self.installedBeforeToday,
            remotePolicy: remotePolicy,
            randomUnits: randomUnits,
            scheduler: scheduler.eraseToAnyScheduler()
        )
    }

    private func remoteMainBannerPolicy(
        percentage: Int? = nil, minDelay: Int? = nil, maxDelay: Int? = nil
    ) -> AppPolicy {
        return AppPolicy(
            mainBannerExposure: .init(
                exposurePercentage: percentage, minDelaySeconds: minDelay, maxDelaySeconds: maxDelay
            )
        )
    }

    private func observeMainBanner(
        _ usecase: AdExposureUsecaseImple, _ receive: @escaping (Bool) -> Void
    ) {
        usecase.isMainBannerAdAllowed
            .sink(receiveValue: receive)
            .store(in: &self.cancelBag)
    }

    @Test("설치 당일이면 뽑혀도 메인 배너를 허용하지 않는다")
    func usecase_whenInstalledToday_mainBannerIsNotAllowed() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(
            coldLaunchHistory: AppColdLaunchHistory() |> \.firstLaunchDate .~ Date(),
            randomUnits: [0, 0],
            scheduler: scheduler
        )
        var alloweds: [Bool] = []

        // when
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(301))

        // then
        #expect(alloweds == [false])
    }

    @Test("이번 실행에 안 뽑히면 지연이 지나도 메인 배너를 허용하지 않는다")
    func usecase_whenNotDrawn_mainBannerIsNotAllowed() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(randomUnits: [0.75, 0], scheduler: scheduler)
        var alloweds: [Bool] = []

        // when
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(301))

        // then
        #expect(alloweds == [false])
    }

    @Test("확률 경계 바로 아래 추첨은 뽑힌다")
    func usecase_whenDrawJustBelowPercentage_mainBannerIsAllowedAfterDelay() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(randomUnits: [0.7499, 0], scheduler: scheduler)
        var alloweds: [Bool] = []

        // when
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(60))

        // then
        #expect(alloweds == [false, true])
    }

    @Test("뽑히면 둘째 추첨값으로 정한 지연 전엔 허용하지 않고 지연 뒤 허용한다")
    func usecase_whenDrawn_mainBannerIsAllowedOnlyAfterDrawnDelay() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(randomUnits: [0.1, 0.5], scheduler: scheduler)
        var alloweds: [Bool] = []

        // when + then
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(179))
        #expect(alloweds == [false])

        scheduler.advance(by: .seconds(1))
        #expect(alloweds == [false, true])
    }

    @Test("추첨은 실행에 한 번이라 다시 구독해도 같은 지연을 쓴다")
    func usecase_whenSubscribedAgain_usesSameDrawnDelay() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(randomUnits: [0.1, 0.5], scheduler: scheduler)
        var firstAlloweds: [Bool] = []
        var secondAlloweds: [Bool] = []

        // when
        self.observeMainBanner(usecase) { firstAlloweds.append($0) }
        self.observeMainBanner(usecase) { secondAlloweds.append($0) }
        scheduler.advance(by: .seconds(180))

        // then
        #expect(firstAlloweds == [false, true])
        #expect(secondAlloweds == [false, true])
    }

    @Test("뽑혀도 유료 플랜이면 지연 뒤 메인 배너를 허용하지 않는다")
    func usecase_whenDrawnButPaidPlan_mainBannerIsNotAllowed() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(
            userPlan: .standard, randomUnits: [0, 0], scheduler: scheduler
        )
        var alloweds: [Bool] = []

        // when
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(60))

        // then
        #expect(alloweds == [false])
    }

    @Test("메인 배너가 뜬 뒤 유료로 바뀌면 내려간다")
    func usecase_whenPlanChangesToPaidAfterShown_mainBannerBecomesNotAllowed() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(randomUnits: [0, 0], scheduler: scheduler)
        var alloweds: [Bool] = []
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(60))

        // when
        self.stubBillingUsecase.currentUserPlanSubject.send(self.userPlan(.lifetime))

        // then
        #expect(alloweds == [false, true, false])
    }

    @Test("리모트 값이 있으면 기본값 대신 쓴다")
    func usecase_whenRemotePolicyExists_usesRemoteValues() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(
            remotePolicy: self.remoteMainBannerPolicy(percentage: 100, minDelay: 10, maxDelay: 20),
            randomUnits: [0.9, 0.5],
            scheduler: scheduler
        )
        var alloweds: [Bool] = []

        // when + then
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(14))
        #expect(alloweds == [false])

        scheduler.advance(by: .seconds(1))
        #expect(alloweds == [false, true])
    }

    @Test("리모트에 없는 속성만 기본값으로 채운다")
    func usecase_whenRemotePolicyHasOnlyMinDelay_fillsRestWithDefault() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(
            remotePolicy: self.remoteMainBannerPolicy(minDelay: 100),
            randomUnits: [0.7, 0.5],
            scheduler: scheduler
        )
        var alloweds: [Bool] = []

        // when + then
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(199))
        #expect(alloweds == [false])

        scheduler.advance(by: .seconds(1))
        #expect(alloweds == [false, true])
    }

    @Test("리모트 확률이 0 이면 어떤 추첨값도 뽑히지 않는다")
    func usecase_whenRemotePercentageIsZero_mainBannerIsNotAllowed() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(
            remotePolicy: self.remoteMainBannerPolicy(percentage: 0),
            randomUnits: [0, 0],
            scheduler: scheduler
        )
        var alloweds: [Bool] = []

        // when
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(301))

        // then
        #expect(alloweds == [false])
    }

    @Test("최소 지연이 최대보다 크면 최소를 지연으로 쓴다")
    func usecase_whenMinDelayIsOverMaxDelay_usesMinDelay() {
        // given
        let scheduler = DispatchQueue.test
        let usecase = self.makeUsecaseForMainBanner(
            remotePolicy: self.remoteMainBannerPolicy(minDelay: 100, maxDelay: 50),
            randomUnits: [0, 0.9],
            scheduler: scheduler
        )
        var alloweds: [Bool] = []

        // when + then
        self.observeMainBanner(usecase) { alloweds.append($0) }
        scheduler.advance(by: .seconds(99))
        #expect(alloweds == [false])

        scheduler.advance(by: .seconds(1))
        #expect(alloweds == [false, true])
    }
}


// MARK: - 전면 광고 미리 로드 여부

extension AdExposureUsecaseImpleTests {

    @Test("무료 플랜이면 전면 광고를 미리 로드한다")
    func usecase_whenFreePlan_shouldPreloadFullScreenAds() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.free))

        // when
        let shouldPreload = usecase.shouldPreloadFullScreenAds()

        // then
        #expect(shouldPreload == true)
    }

    @Test("유료 플랜이면 전면 광고를 미리 로드하지 않는다")
    func usecase_whenPaidPlan_shouldNotPreloadFullScreenAds() {
        // given
        let usecase = self.makeUsecase(userPlan: self.userPlan(.standard))

        // when
        let shouldPreload = usecase.shouldPreloadFullScreenAds()

        // then
        #expect(shouldPreload == false)
    }

    @Test("플랜을 아직 모르면 전면 광고를 미리 로드한다")
    func usecase_whenUserPlanUnknown_shouldPreloadFullScreenAds() {
        // given
        let usecase = self.makeUsecase(userPlan: nil)

        // when
        let shouldPreload = usecase.shouldPreloadFullScreenAds()

        // then
        #expect(shouldPreload == true)
    }
}


// MARK: - 플랜·설치 경과일

extension AdExposureUsecaseImpleTests {

    @Test("유료 플랜이면 전면 광고를 허용하지 않는다")
    func usecase_whenPaidPlan_isNotAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.standard), coldLaunchHistory: self.installedBeforeToday
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == false)
    }

    @Test("플랜을 모르면 전면 광고를 허용하지 않는다")
    func usecase_whenUserPlanUnknown_isNotAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: nil, coldLaunchHistory: self.installedBeforeToday
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == false)
    }

    @Test("설치 당일이면 전면 광고를 허용하지 않는다")
    func usecase_whenInstalledToday_isNotAllowed() {
        // given
        let history = AppColdLaunchHistory()
            |> \.firstLaunchDate .~ self.now.addingTimeInterval(-3600)
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.free), coldLaunchHistory: history
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == false)
    }

    @Test("설치 다음 날이고 노출 이력이 없으면 전면 광고를 허용한다")
    func usecase_whenInstalledBeforeTodayAndNoExposure_isAllowed() {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.free), coldLaunchHistory: self.installedBeforeToday
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == true)
    }
}


// MARK: - 하루 상한·노출 간격

extension AdExposureUsecaseImpleTests {

    private func makeUsecaseForExposureLimit(
        record: FullScreenAdExposureRecord
    ) -> AdExposureUsecaseImple {
        return self.makeUsecase(
            userPlan: self.userPlan(.free),
            exposureRecord: record,
            coldLaunchHistory: self.installedBeforeToday
        )
    }

    @Test("오늘 3회 노출했으면 전면 광고를 허용하지 않는다")
    func usecase_whenExposedThreeTimesToday_isNotAllowed() {
        // given
        let usecase = self.makeUsecaseForExposureLimit(
            record: self.exposureRecord(secondsAgo: 3600, countOfDay: 3)
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == false)
    }

    @Test("오늘 2회 노출했고 30분이 지났으면 전면 광고를 허용한다")
    func usecase_whenExposedTwiceTodayAndIntervalPassed_isAllowed() {
        // given
        let usecase = self.makeUsecaseForExposureLimit(
            record: self.exposureRecord(secondsAgo: 3600, countOfDay: 2)
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == true)
    }

    @Test("마지막 노출 후 30분이 안 됐으면 전면 광고를 허용하지 않는다")
    func usecase_whenIntervalIsUnderThirtyMinutes_isNotAllowed() {
        // given
        let usecase = self.makeUsecaseForExposureLimit(
            record: self.exposureRecord(secondsAgo: 30 * 60 - 1, countOfDay: 1)
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == false)
    }

    @Test("마지막 노출 후 정확히 30분이 지났으면 전면 광고를 허용한다")
    func usecase_whenIntervalIsExactlyThirtyMinutes_isAllowed() {
        // given
        let usecase = self.makeUsecaseForExposureLimit(
            record: self.exposureRecord(secondsAgo: 30 * 60, countOfDay: 1)
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == true)
    }

    @Test("날짜가 바뀌면 횟수를 다시 센다")
    func usecase_whenDayChanged_countRestarts() {
        // given
        let usecase = self.makeUsecaseForExposureLimit(
            record: self.exposureRecord(secondsAgo: 6 * 3600, countOfDay: 3)
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: self.now)

        // then
        #expect(canExpose == true)
    }

    @Test("날짜가 바뀌어도 30분이 안 됐으면 전면 광고를 허용하지 않는다")
    func usecase_whenDayChangedButIntervalNotPassed_isNotAllowed() {
        // given
        let startOfToday = self.calendar.startOfDay(for: self.now)
        let usecase = self.makeUsecaseForExposureLimit(
            record: .init(lastExposeDate: startOfToday.addingTimeInterval(-600), countOfDay: 1)
        )

        // when
        let canExpose = usecase.canExposeFullScreenAd(at: startOfToday.addingTimeInterval(300))

        // then
        #expect(canExpose == false)
    }
}


// MARK: - 노출 기록

extension AdExposureUsecaseImpleTests {

    @Test("같은 날 노출을 기록하면 횟수가 1 늘어난다")
    func usecase_recordInSameDay_increaseCount() {
        // given
        let usecase = self.makeUsecase(
            exposureRecord: self.exposureRecord(secondsAgo: 3600, countOfDay: 2)
        )

        // when
        usecase.recordFullScreenAdExposed(at: self.now)

        // then
        #expect(self.spyAdRepository.didUpdatedExposureRecord
                == .init(lastExposeDate: self.now, countOfDay: 3))
    }

    @Test("다른 날 노출을 기록하면 횟수가 1부터 시작한다")
    func usecase_recordInOtherDay_restartCount() {
        // given
        let usecase = self.makeUsecase(
            exposureRecord: self.exposureRecord(secondsAgo: 6 * 3600, countOfDay: 3)
        )

        // when
        usecase.recordFullScreenAdExposed(at: self.now)

        // then
        #expect(self.spyAdRepository.didUpdatedExposureRecord
                == .init(lastExposeDate: self.now, countOfDay: 1))
    }

    @Test("노출 이력이 없을 때 기록하면 횟수가 1이다")
    func usecase_recordWithoutHistory_countIsOne() {
        // given
        let usecase = self.makeUsecase()

        // when
        usecase.recordFullScreenAdExposed(at: self.now)

        // then
        #expect(self.spyAdRepository.didUpdatedExposureRecord
                == .init(lastExposeDate: self.now, countOfDay: 1))
    }
}


// MARK: - 이벤트 저장 차례

extension AdExposureUsecaseImpleTests {

    @Test("이벤트를 저장한 적 없으면 전면 차례가 아니다")
    func usecase_whenNeverSavedEvent_isNotFullScreenAdTurn() {
        // given
        let usecase = self.makeUsecase(eventSavedCount: 0)

        // when
        let isTurn = usecase.isFullScreenAdTurnAfterEventSave()

        // then
        #expect(isTurn == false)
    }

    @Test("이벤트를 한 번 저장했으면 전면 차례가 아니다")
    func usecase_whenSavedEventOnce_isNotFullScreenAdTurn() {
        // given
        let usecase = self.makeUsecase(eventSavedCount: 1)

        // when
        let isTurn = usecase.isFullScreenAdTurnAfterEventSave()

        // then
        #expect(isTurn == false)
    }

    @Test("이벤트를 두 번 저장했으면 전면 차례다")
    func usecase_whenSavedEventTwice_isFullScreenAdTurn() {
        // given
        let usecase = self.makeUsecase(eventSavedCount: 2)

        // when
        let isTurn = usecase.isFullScreenAdTurnAfterEventSave()

        // then
        #expect(isTurn == true)
    }

    @Test("이벤트를 세 번 저장했으면 전면 차례가 아니다")
    func usecase_whenSavedEventThreeTimes_isNotFullScreenAdTurn() {
        // given
        let usecase = self.makeUsecase(eventSavedCount: 3)

        // when
        let isTurn = usecase.isFullScreenAdTurnAfterEventSave()

        // then
        #expect(isTurn == false)
    }

    @Test("이벤트 저장을 기록하면 횟수가 1 늘어난다")
    func usecase_recordEventSaved_increaseCount() {
        // given
        let usecase = self.makeUsecase(eventSavedCount: 3)

        // when
        usecase.recordEventSavedForFullScreenAd()

        // then
        #expect(self.spyAdRepository.didUpdatedEventSavedCount == 4)
    }
}


// MARK: - 추적 요청 가부

extension AdExposureUsecaseImpleTests {

    @Test("저장된 이벤트가 있고 안내를 아직 안 봤으면 추적을 요청할 수 있다")
    func usecase_whenUserHasEvent_canRequestTrackingAuthorization() async {
        // given
        let usecase = self.makeUsecase(hasAnyEvent: true, hasShownTrackingGuide: false)

        // when
        let canRequest = await usecase.canRequestTrackingAuthorization()

        // then
        #expect(canRequest == true)
    }

    @Test("저장된 이벤트가 없으면 추적을 요청하지 않는다")
    func usecase_whenUserHasNoEvent_cannotRequestTrackingAuthorization() async {
        // given
        let usecase = self.makeUsecase(hasAnyEvent: false, hasShownTrackingGuide: false)

        // when
        let canRequest = await usecase.canRequestTrackingAuthorization()

        // then
        #expect(canRequest == false)
    }

    @Test("이벤트 조회가 실패하면 추적을 요청하지 않는다")
    func usecase_whenEventExistenceFetchFails_cannotRequestTrackingAuthorization() async {
        // given
        let usecase = self.makeUsecase(
            hasAnyEvent: true, shouldFailEventExistenceFetch: true
        )

        // when
        let canRequest = await usecase.canRequestTrackingAuthorization()

        // then
        #expect(canRequest == false)
    }

    @Test("안내를 이미 본 유저에게는 다시 요청하지 않는다")
    func usecase_whenTrackingGuideAlreadyShown_cannotRequestTrackingAuthorization() async {
        // given
        let usecase = self.makeUsecase(hasAnyEvent: true, hasShownTrackingGuide: true)

        // when
        let canRequest = await usecase.canRequestTrackingAuthorization()

        // then
        #expect(canRequest == false)
    }

    @Test("추적 권한을 이미 정한 유저에게는 다시 요청하지 않는다")
    func usecase_whenTrackingAuthorizationDetermined_cannotRequestTrackingAuthorization() async {
        // given
        let usecase = self.makeUsecase(
            hasAnyEvent: true, isTrackingAuthorizationDetermined: true
        )

        // when
        let canRequest = await usecase.canRequestTrackingAuthorization()

        // then
        #expect(canRequest == false)
    }

    @Test("유료 플랜이어도 추적 요청 가부는 플랜을 보지 않는다")
    func usecase_whenPaidPlan_canRequestTrackingAuthorization() async {
        // given
        let usecase = self.makeUsecase(
            userPlan: self.userPlan(.standard), hasAnyEvent: true
        )

        // when
        let canRequest = await usecase.canRequestTrackingAuthorization()

        // then
        #expect(canRequest == true)
    }

    @Test("안내 노출을 기록하면 저장소에 남고 다음부터 요청하지 않는다")
    func usecase_recordTrackingGuideShown_marksShownOnRepository() async {
        // given
        let usecase = self.makeUsecase(hasAnyEvent: true)

        // when
        usecase.recordTrackingGuideShown()

        // then
        #expect(self.spyAdRepository.didMarkTrackingGuideShown == true)
        #expect(await usecase.canRequestTrackingAuthorization() == false)
    }
}


private final class StubRandomUnits: @unchecked Sendable {

    private var units: [Double]

    init(_ units: [Double]) {
        self.units = units
    }

    @Sendable
    func next() -> Double {
        return self.units.isEmpty ? 0.99 : self.units.removeFirst()
    }
}
