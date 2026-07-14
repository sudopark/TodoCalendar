//
//  ApplicationRootViewModelImpleTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import Scenes
import TestDoubles
import UnitTestHelpKit

@testable import TodoCalendarApp


final class ApplicationRootViewModelImpleTests {

    private let spyAIJobRefreshUsecase = SpyAIJobRefreshUsecase()

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
            appUpdateCheckUsecase: StubAppUpdateCheckUsecase()
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


// MARK: - doubles

private final class SpyAIJobRefreshUsecase: AIJobRefreshUsecase, @unchecked Sendable {

    var didHandleJobStatusChangedWith: String?
    func handleJobStatusChanged(_ jobId: String) {
        self.didHandleJobStatusChangedWith = jobId
    }

    var didRefreshProcessingJob: Bool?
    func refreshProcessingJobIfNeeded() {
        self.didRefreshProcessingJob = true
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

private final class StubAppUpdateCheckUsecase: AppUpdateCheckUsecase, @unchecked Sendable {

    func checkUpdateIsNeed() { }

    var updateRequirement: AnyPublisher<AppUpdateRequirement, Never> {
        return Empty().eraseToAnyPublisher()
    }

    var isUpdateAvailable: AnyPublisher<Bool, Never> {
        return Empty().eraseToAnyPublisher()
    }
}
