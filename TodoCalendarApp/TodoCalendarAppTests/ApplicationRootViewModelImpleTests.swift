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

    private let spyAppUpdateCheckUsecase = SpyAppUpdateCheckUsecase()
    private let fakeAccountUsecase = FakeAccountUsecase()

    private func makeViewModel() -> ApplicationRootViewModelImple {
        return ApplicationRootViewModelImple(
            authUsecase: StubAuthUsecase(),
            accountUsecase: self.fakeAccountUsecase,
            prepareUsecase: StubApplicationPrepareUsecase(),
            deepLinkHandler: ApplicationDeepLinkHandlerImple(),
            externalCalendarServiceUsecase: StubExternalCalendarIntegrationUsecase([]),
            userNotificationUsecase: StubUserNotificationUsecase(),
            backgroundEventSyncUsecase: StubBackgroundEventSyncUsecase(),
            appUpdateCheckUsecase: self.spyAppUpdateCheckUsecase,
        )
    }
}


// MARK: - 푸시 payload 분기

extension ApplicationRootViewModelImpleTests {

    @Test("jobId가 담긴 푸시는 메인 화면으로 AI job 갱신을 내려보낸다")
    func viewModel_whenPushHasJobId_routeToMainScene() async {
        // given
        let viewModel = self.makeViewModel()
        let spyInteractor = SpyMainSceneInteractor()
        await viewModel.attach(mainSceneInteractor: spyInteractor)

        // when
        viewModel.handleReceivePushNotification(
            userInfo: ["jobId": "some_job", "status": "DONE"]
        )
        try? await Task.sleep(for: .milliseconds(100))

        // then
        #expect(spyInteractor.didHandleAIJobStatusChangedWith == "some_job")
    }

    @Test("jobId가 없는 푸시는 메인 화면에 아무것도 내려보내지 않는다")
    func viewModel_whenPushHasNoJobId_doNotRouteToMainScene() async {
        // given
        let viewModel = self.makeViewModel()
        let spyInteractor = SpyMainSceneInteractor()
        await viewModel.attach(mainSceneInteractor: spyInteractor)

        // when
        viewModel.handleReceivePushNotification(
            userInfo: ["aps": ["alert": "이벤트 알림"]]
        )
        try? await Task.sleep(for: .milliseconds(100))

        // then
        #expect(spyInteractor.didHandleAIJobStatusChangedWith == nil)
    }
}


// MARK: - 앱 활성 상태 전환

extension ApplicationRootViewModelImpleTests {

    @Test("포그라운드 복귀는 업데이트 체크를 수행한다")
    func viewModel_whenWillEnterForeground_checkUpdate() async {
        // given
        let viewModel = self.makeViewModel()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
        try? await Task.sleep(for: .milliseconds(100))

        // then
        #expect(self.spyAppUpdateCheckUsecase.didCheckUpdateIsNeed == true)
        withExtendedLifetime(viewModel) { }
    }
}



private final class FakeAccountUsecase: StubAccountUsecase, @unchecked Sendable {

    private let statusSubject = PassthroughSubject<AccountChangedEvent, Never>()

    override var accountStatusChanged: AnyPublisher<AccountChangedEvent, Never> {
        return self.statusSubject.eraseToAnyPublisher()
    }

    func sendSignOut() {
        self.statusSubject.send(.signOut)
    }
}

private final class SpyMainSceneInteractor: MainSceneInteractor, @unchecked Sendable {

    var didHandleAIJobStatusChangedWith: String?
    func handleAIJobStatusChanged(_ jobId: String) {
        self.didHandleAIJobStatusChangedWith = jobId
    }

    func calendarScene(focusChangedTo selected: SelectDayInfo) { }
    func daySelectDialog(didSelect day: SelectDayInfo) { }
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

