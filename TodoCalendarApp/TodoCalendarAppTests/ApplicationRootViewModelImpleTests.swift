//
//  ApplicationRootViewModelImpleTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Testing
import Combine
import Domain
import Scenes
import TestDoubles
import UnitTestHelpKit

@testable import TodoCalendarApp


final class ApplicationRootViewModelImpleTests {

    private let spyAIJobRefreshUsecase = SpyAIJobRefreshUsecase()
    private let spyAppUpdateCheckUsecase = SpyAppUpdateCheckUsecase()

    private func makeViewModel() -> ApplicationRootViewModelImple {
        return ApplicationRootViewModelImple(
            authUsecase: StubAuthUsecase(),
            accountUsecase: StubAccountUsecase(),
            prepareUsecase: StubApplicationPrepareUsecase(),
            deepLinkHandler: ApplicationDeepLinkHandlerImple(),
            externalCalendarServiceUsecase: StubExternalCalendarIntegrationUsecase([]),
            userNotificationUsecase: StubUserNotificationUsecase(),
            backgroundEventSyncUsecase: StubBackgroundEventSyncUsecase(),
            aiJobRefreshUsecase: self.spyAIJobRefreshUsecase,
            appUpdateCheckUsecase: self.spyAppUpdateCheckUsecase
        )
    }
}


// MARK: - 푸시 payload 분기

extension ApplicationRootViewModelImpleTests {

    @Test("jobId가 담긴 푸시는 AI job 즉시 조회로 라우팅한다")
    func viewModel_whenPushHasJobId_routeToAIJobRefresh() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.handleReceivePushNotification(
            userInfo: ["jobId": "some_job", "status": "DONE"]
        )

        // then
        #expect(self.spyAIJobRefreshUsecase.didHandleJobStatusChangedWith == "some_job")
    }

    @Test("jobId가 없는 푸시는 AI job 조회를 트리거하지 않는다")
    func viewModel_whenPushHasNoJobId_doNotRouteToAIJobRefresh() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.handleReceivePushNotification(
            userInfo: ["aps": ["alert": "이벤트 알림"]]
        )

        // then
        #expect(self.spyAIJobRefreshUsecase.didHandleJobStatusChangedWith == nil)
    }
}


// MARK: - 앱 활성 상태 전환

extension ApplicationRootViewModelImpleTests {

    @Test("앱이 활성 상태가 되면 처리중인 AI job을 이어받는다")
    func viewModel_whenDidBecomeActive_refreshProcessingJob() async {
        // given
        let viewModel = self.makeViewModel()

        // when
        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        try? await Task.sleep(for: .milliseconds(100))

        // then
        #expect(self.spyAIJobRefreshUsecase.didRefreshProcessingJobTimes == 1)
        withExtendedLifetime(viewModel) { }
    }

    // didBecomeActive는 제어센터·알림센터 여닫기, 권한 다이얼로그 dismiss 등에서도 매번 온다.
    // 그때마다 재조회하면 job 진행 중 구간에 불필요한 서버 조회가 반복된다.
    @Test("짧은 간격의 연속 활성 전환은 한 번만 이어받는다")
    func viewModel_whenDidBecomeActiveRepeatedly_refreshOnlyOnce() async {
        // given
        let viewModel = self.makeViewModel()

        // when
        (0..<3).forEach { _ in
            NotificationCenter.default.post(
                name: UIApplication.didBecomeActiveNotification, object: nil
            )
        }
        try? await Task.sleep(for: .milliseconds(100))

        // then
        #expect(self.spyAIJobRefreshUsecase.didRefreshProcessingJobTimes == 1)
        withExtendedLifetime(viewModel) { }
    }

    @Test("포그라운드 복귀는 업데이트 체크만 하고 AI job은 이어받지 않는다")
    func viewModel_whenWillEnterForeground_onlyCheckUpdate() async {
        // given
        let viewModel = self.makeViewModel()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
        try? await Task.sleep(for: .milliseconds(100))

        // then
        #expect(self.spyAppUpdateCheckUsecase.didCheckUpdateIsNeed == true)
        #expect(self.spyAIJobRefreshUsecase.didRefreshProcessingJobTimes == 0)
        withExtendedLifetime(viewModel) { }
    }
}


// MARK: - doubles

private final class SpyAIJobRefreshUsecase: AIJobRefreshUsecase, @unchecked Sendable {

    var didHandleJobStatusChangedWith: String?
    func handleJobStatusChanged(_ jobId: String) {
        self.didHandleJobStatusChangedWith = jobId
    }

    var didRefreshProcessingJobTimes: Int = 0
    func refreshProcessingJobIfNeeded() {
        self.didRefreshProcessingJobTimes += 1
    }

    var didChangeFactory: Bool?
    func change(factory: any UsecaseFactory) {
        self.didChangeFactory = true
    }
}

private final class StubApplicationPrepareUsecase: ApplicationPrepareUsecase {

    func prepareLaunch() async throws -> ApplicationPrepareResult {
        return ApplicationPrepareResult(
            latestLoginAcount: nil,
            appearnceSetings: AppearanceSettings(
                calendar: .init(colorSetKey: .systemTheme, fontSetKey: .systemDefault),
                defaultTagColor: .init(holiday: "", default: "")
            )
        )
    }

    func prepareEnterBackground() { }

    func prepareSignedIn(_ auth: Auth) async { }

    func prepareSignedOut() async { }

    func prepareExternalCalendarIntegrated(_ serviceId: String) { }

    func prepareExternalCalendarStopIntegrated(_ serviceId: String) { }
}

private final class StubUserNotificationUsecase: UserNotificationUsecase, @unchecked Sendable {

    func register(fcmToken: String) async throws { }
}

private final class StubBackgroundEventSyncUsecase: BackgroundEventSyncUsecase, @unchecked Sendable {

    func change(factory: any UsecaseFactory) { }

    func scheduleTask() { }

    func registerTask() { }
}

private final class SpyAppUpdateCheckUsecase: AppUpdateCheckUsecase, @unchecked Sendable {

    var didCheckUpdateIsNeed: Bool?
    func checkUpdateIsNeed() {
        self.didCheckUpdateIsNeed = true
    }

    var updateRequirement: AnyPublisher<AppUpdateRequirement, Never> {
        return Empty().eraseToAnyPublisher()
    }

    var isUpdateAvailable: AnyPublisher<Bool, Never> {
        return Empty().eraseToAnyPublisher()
    }
}
