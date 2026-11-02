//
//  AppReviewRequestUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


struct AppReviewRequestUsecaseImpleTests {

    private final class StubRepository: AppUsageRecordRepository, @unchecked Sendable {

        private var savedNewEventCount: Int
        private var lastReviewRequestedAppVersion: String?

        init(savedNewEventCount: Int, lastReviewRequestedAppVersion: String?) {
            self.savedNewEventCount = savedNewEventCount
            self.lastReviewRequestedAppVersion = lastReviewRequestedAppVersion
        }

        func loadSavedNewEventCount() -> Int {
            return self.savedNewEventCount
        }

        func increaseSavedNewEventCount() {
            self.savedNewEventCount += 1
        }

        func loadLastReviewRequestedAppVersion() -> String? {
            return self.lastReviewRequestedAppVersion
        }

        var didSaveLastReviewRequestedAppVersion: String?

        func saveLastReviewRequestedAppVersion(_ version: String) {
            self.didSaveLastReviewRequestedAppVersion = version
            self.lastReviewRequestedAppVersion = version
        }
    }

    private func makeUsecase(
        savedNewEventCount: Int = 5,
        lastReviewRequestedAppVersion: String? = nil,
        plan: BillingUserPlan? = BillingUserPlan() |> \.planId .~ .free,
        appVersion: String? = "3.1.2",
        repository: StubRepository? = nil
    ) -> AppReviewRequestUsecaseImple {
        return AppReviewRequestUsecaseImple(
            repository: repository ?? StubRepository(
                savedNewEventCount: savedNewEventCount,
                lastReviewRequestedAppVersion: lastReviewRequestedAppVersion
            ),
            planSource: StubBillingUserPlanSource(plan: plan),
            deviceInfoFetchService: StubDeviceInfoFetchService(stubAppVersion: appVersion)
        )
    }
}


// MARK: - 새 이벤트 저장 수

extension AppReviewRequestUsecaseImpleTests {

    @Test("새 이벤트 저장 수가 5 미만이면 리뷰를 요청할 수 없다")
    func usecase_whenSavedCountBelowThreshold_cannotRequest() {
        // given
        let usecase = self.makeUsecase(savedNewEventCount: 4)

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == false)
    }

    @Test("새 이벤트 저장 수가 5 에 닿으면 리뷰를 요청할 수 있다")
    func usecase_whenSavedCountReachesThreshold_canRequest() {
        // given
        let usecase = self.makeUsecase(savedNewEventCount: 5)

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == true)
    }

    @Test("새 이벤트 저장을 기록하면 저장 수가 하나 늘어 문턱에 닿는다")
    func usecase_recordNewEventSaved_increasesSavedCount() {
        // given
        let usecase = self.makeUsecase(savedNewEventCount: 4)

        // when
        let canRequestBefore = usecase.canRequestReview()
        usecase.recordNewEventSaved()
        let canRequestAfter = usecase.canRequestReview()

        // then
        #expect(canRequestBefore == false)
        #expect(canRequestAfter == true)
    }
}


// MARK: - 앱 버전

extension AppReviewRequestUsecaseImpleTests {

    @Test("이번 버전에 이미 리뷰를 요청했으면 다시 요청할 수 없다")
    func usecase_whenAlreadyRequestedInCurrentVersion_cannotRequest() {
        // given
        let usecase = self.makeUsecase(lastReviewRequestedAppVersion: "3.1.2", appVersion: "3.1.2")

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == false)
    }

    @Test("이전 버전에 리뷰를 요청했으면 이번 버전에 다시 요청할 수 있다")
    func usecase_whenRequestedInPreviousVersion_canRequest() {
        // given
        let usecase = self.makeUsecase(lastReviewRequestedAppVersion: "3.1.1", appVersion: "3.1.2")

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == true)
    }

    @Test("앱 버전을 모르면 리뷰를 요청할 수 없고 요청 기록도 남기지 않는다")
    func usecase_whenAppVersionIsUnknown_cannotRequest() {
        // given
        let repository = StubRepository(savedNewEventCount: 5, lastReviewRequestedAppVersion: nil)
        let usecase = self.makeUsecase(appVersion: nil, repository: repository)

        // when
        let canRequest = usecase.canRequestReview()
        usecase.markReviewRequested()

        // then
        #expect(canRequest == false)
        #expect(repository.didSaveLastReviewRequestedAppVersion == nil)
    }

    @Test("리뷰 요청을 기록하면 현재 앱 버전을 저장하고 이번 버전엔 더 요청할 수 없다")
    func usecase_markReviewRequested_savesCurrentVersion() {
        // given
        let repository = StubRepository(savedNewEventCount: 5, lastReviewRequestedAppVersion: "3.1.1")
        let usecase = self.makeUsecase(appVersion: "3.1.2", repository: repository)

        // when
        usecase.markReviewRequested()
        let canRequest = usecase.canRequestReview()

        // then
        #expect(repository.didSaveLastReviewRequestedAppVersion == "3.1.2")
        #expect(canRequest == false)
    }
}


// MARK: - 유저 플랜

extension AppReviewRequestUsecaseImpleTests {

    @Test("유료 유저는 리뷰를 요청할 수 없다", arguments: [BillingPlanId.standard, .lifetime])
    func usecase_whenUserIsPaid_cannotRequest(_ planId: BillingPlanId) {
        // given
        let usecase = self.makeUsecase(plan: BillingUserPlan() |> \.planId .~ planId)

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == false)
    }

    @Test("플랜은 받았는데 플랜 id 를 모르면 리뷰를 요청할 수 없다")
    func usecase_whenPlanIdIsUnknown_cannotRequest() {
        // given
        let usecase = self.makeUsecase(plan: BillingUserPlan())

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == false)
    }

    @Test("플랜을 아직 못 받았으면 무료로 보고 리뷰를 요청할 수 있다")
    func usecase_whenPlanIsNotLoaded_canRequest() {
        // given
        let usecase = self.makeUsecase(plan: nil)

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == true)
    }

    @Test("무료 유저는 리뷰를 요청할 수 있다")
    func usecase_whenUserIsFree_canRequest() {
        // given
        let usecase = self.makeUsecase(plan: BillingUserPlan() |> \.planId .~ .free)

        // when
        let canRequest = usecase.canRequestReview()

        // then
        #expect(canRequest == true)
    }
}
