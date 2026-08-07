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

    private let callOrder = CallOrderRecorder()
    private let spyAppUpdateCheckUsecase = SpyAppUpdateCheckUsecase()
    private let fakeAccountUsecase = FakeAccountUsecase()
    private lazy var spyAIJobRefreshUsecase = SpyAIJobRefreshUsecase(recorder: self.callOrder)

    private func makeViewModel() -> ApplicationRootViewModelImple {
        return ApplicationRootViewModelImple(
            authUsecase: StubAuthUsecase(),
            accountUsecase: self.fakeAccountUsecase,
            prepareUsecase: StubApplicationPrepareUsecase(recorder: self.callOrder),
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


// MARK: - 로그아웃

extension ApplicationRootViewModelImpleTests {

    // 로컬 AI 커맨드 기록은 로그인 유저의 DB에 있다 — prepareSignedOut이 DB를 닫고
    // 익명 DB로 갈아끼우기 전에 지워야 재로그인 때 죽은 job이 되살아나지 않는다.
    @Test("로그아웃하면 DB 정리보다 AI 커맨드 정리를 먼저 끝낸다")
    func viewModel_whenSignedOut_clearAICommandBeforeDatabaseSwap() async {
        // given
        let viewModel = self.makeViewModel()

        // when
        self.fakeAccountUsecase.sendSignOut()
        try? await Task.sleep(for: .milliseconds(300))

        // then
        #expect(self.callOrder.calls == ["aiHandleSignedOut", "prepareSignedOut"])
        withExtendedLifetime(viewModel) { }
    }
}


// MARK: - doubles

private final class CallOrderRecorder: @unchecked Sendable {

    private(set) var calls: [String] = []

    func record(_ name: String) {
        self.calls.append(name)
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

private final class SpyAIJobRefreshUsecase: AIJobRefreshUsecase, @unchecked Sendable {

    private let recorder: CallOrderRecorder

    init(recorder: CallOrderRecorder) {
        self.recorder = recorder
    }

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

    func handleSignedOut() async {
        self.recorder.record("aiHandleSignedOut")
    }
}

private final class StubApplicationPrepareUsecase: ApplicationPrepareUsecase {

    private let recorder: CallOrderRecorder

    init(recorder: CallOrderRecorder) {
        self.recorder = recorder
    }

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

    func prepareSignedOut() async {
        self.recorder.record("prepareSignedOut")
    }

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
