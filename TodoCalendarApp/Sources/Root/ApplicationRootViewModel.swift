//
//  ApplicationRootViewModel.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import WidgetKit
import Combine
import Prelude
import Optics
import Domain
import Repository
import Scenes
import Extensions


final class ApplicationRootViewModelImple: @unchecked Sendable {
 
    private let authUsecase: any AuthUsecase
    private let accountUsecase: any AccountUsecase
    private let prepareUsecase: any ApplicationPrepareUsecase
    private let deepLinkHandler: ApplicationDeepLinkHandlerImple
    private let externalCalendarServiceUsecase: any ExternalCalendarIntegrationUsecase
    private let userNotificationUsecase: any UserNotificationUsecase
    private let backgroundEventSyncUsecase: any BackgroundEventSyncUsecase
    private let aiJobRefreshUsecase: any AIJobRefreshUsecase
    private let appUpdateCheckUsecase: any AppUpdateCheckUsecase
    var router: ApplicationRootRouter?

    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        prepareUsecase: any ApplicationPrepareUsecase,
        deepLinkHandler: ApplicationDeepLinkHandlerImple,
        externalCalendarServiceUsecase: any ExternalCalendarIntegrationUsecase,
        userNotificationUsecase: any UserNotificationUsecase,
        backgroundEventSyncUsecase: any BackgroundEventSyncUsecase,
        aiJobRefreshUsecase: any AIJobRefreshUsecase,
        appUpdateCheckUsecase: any AppUpdateCheckUsecase
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.prepareUsecase = prepareUsecase
        self.deepLinkHandler = deepLinkHandler
        self.externalCalendarServiceUsecase = externalCalendarServiceUsecase
        self.userNotificationUsecase = userNotificationUsecase
        self.backgroundEventSyncUsecase = backgroundEventSyncUsecase
        self.aiJobRefreshUsecase = aiJobRefreshUsecase
        self.appUpdateCheckUsecase = appUpdateCheckUsecase

        self.bindAccountStatusChanged()
        self.bindApplicationStatusChanged()
        self.bindExternalCalenarIntegratedStatus()
        self.bindUpdateRequirement()
    }
    
    private struct Subject {
        let fcmToken = CurrentValueSubject<String?, Never>(nil)
        let isSignIn = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}


// MARK: - handle root routing

extension ApplicationRootViewModelImple: AutenticatorTokenRefreshListener {

    func registerBackgroundTask() {
        self.backgroundEventSyncUsecase.registerTask()
    }

    func prepareInitialScene() {
        Task {
            let result = try await self.prepareUsecase.prepareLaunch()
            self.router?.setupInitialScene(result)
            self.subject.isSignIn.send(result.latestLoginAcount != nil)
            self.registerTokenIfNeed()
            self.appUpdateCheckUsecase.checkUpdateIsNeed()
        }
    }
    
    private func bindAccountStatusChanged() {
        
        self.accountUsecase.accountStatusChanged
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] status in
                logger.log(level: .info, "user signIn status changed, isSignIn?: \(status.isSignIn)")
                switch status {
                case .signedIn(let account):
                    self?.handleUserSignedIn(account)
                case .signOut:
                    self?.handleUserSignedOut()
                }
            })
            .store(in: &self.cancellables)
    }
    
    private func bindExternalCalenarIntegratedStatus() {
        self.externalCalendarServiceUsecase.integrationStatusChanged
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] status in
                switch status {
                case .integrated:
                    self?.prepareUsecase.prepareExternalCalendarIntegrated(status.serviceId)
                case .disconnected:
                    self?.prepareUsecase.prepareExternalCalendarStopIntegrated(status.serviceId)
                }
            })
            .store(in: &self.cancellables)
    }
    
    private func handleUserSignedIn(_ account: Account) {
        Task { [weak self] in
            self?.subject.isSignIn.send(true)
            await self?.prepareUsecase.prepareSignedIn(account.auth)
            
            try? await Task.sleep(for: .milliseconds(100))
            self?.router?.changeRootSceneAfter(signIn: account.auth)
            self?.registerTokenIfNeed()
        }
        .store(in: &self.cancellables)
    }
    
    private func handleUserSignedOut() {
        Task { [weak self] in
            self?.subject.isSignIn.send(false)
            // DB가 닫히기 전에 로컬 AI 커맨드 기록을 지워야 재로그인 때 되살아나지 않는다
            await self?.aiJobRefreshUsecase.handleSignedOut()
            await self?.prepareUsecase.prepareSignedOut()
            
            try? await Task.sleep(for: .milliseconds(100))
            self?.router?.changeRootSceneAfter(signIn: nil)
        }
    }
    
    func oauthAutenticator(
        _ authenticator: (any APIAuthenticator)?, didRefresh credential: APICredential
    ) {
        // do nothing
    }
    
    func oauthAutenticator(
        _ authenticator: (any APIAuthenticator)?, didRefreshFailed error: any Error
    ) {
        switch authenticator {
        case is CalendarAPIAutenticator:
            self.handleUserSignedOut()
            
        case is GoogleAPIAuthenticator:
            // TODO: clear shared google calendar events
            self.showExternalServiceAccessTokenExpired(
                "external_service.name::google".localized()
            )
            
        default: break
        }
    }
    
    private func showExternalServiceAccessTokenExpired(_ serviceName: String) {
        let message = "external_service.expired::message".localized(with: serviceName)
        let info = ConfirmDialogInfo()
            |> \.message .~ message
            |> \.withCancel .~ false
        self.router?.showConfirm(dialog: info)
    }
}

// MARK: - handle application status chanegd

extension ApplicationRootViewModelImple {
    
    private func bindApplicationStatusChanged() {

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink(receiveValue: { [weak self] _ in
                self?.handleDidEnterBackground()
            })
            .store(in: &self.cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink(receiveValue: { [weak self] _ in
                self?.handleWillEnterForeground()
            })
            .store(in: &self.cancellables)

        // 제어센터·알림센터 여닫기로도 매번 오지만 상한을 두지 않는다 — throttle은 창에 갇힌
        // 이벤트를 버리지 않고 창 끝까지 미뤄서, 백그라운드 복귀의 job 갱신이 최대 창 길이만큼
        // 늦어졌다 (#795). 진행 중 job이 없으면 refreshProcessingJobIfNeeded가 로컬 조회로
        // 끝나 잦은 호출의 비용도 낮다.
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink(receiveValue: { [weak self] _ in
                self?.handleDidBecomeActive()
            })
            .store(in: &self.cancellables)
    }

    private func handleDidEnterBackground() {
        self.prepareUsecase.prepareEnterBackground()
        self.backgroundEventSyncUsecase.scheduleTask()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handleWillEnterForeground() {
        self.appUpdateCheckUsecase.checkUpdateIsNeed()
    }

    // Siri 인텐트는 앱을 background로 내리지 않아 포그라운드 복귀 이벤트가 오지 않는다.
    // active 전환은 그 경우까지 덮는다.
    private func handleDidBecomeActive() {
        self.aiJobRefreshUsecase.refreshProcessingJobIfNeeded()
    }

    private func bindUpdateRequirement() {
        self.appUpdateCheckUsecase.updateRequirement
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] requirement in
                self?.router?.showUpdatePopup(requirement)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - handle url

extension ApplicationRootViewModelImple {
    
    func handle(open url: URL) -> Bool {
        
        if self.externalCalendarServiceUsecase.handleAuthenticationResultOrNot(open: url) {
            return true
        }
        
        if self.authUsecase.handleAuthenticationResultOrNot(open: url) {
            return true
        }
        
        if self.deepLinkHandler.handleLink(url) {
            return true
        }
        
        return false
    }
}

// MARK: - fcm token

extension ApplicationRootViewModelImple {
    
    func handleReceiveFcmToken(_ token: String) {
        self.subject.fcmToken.send(token)
        self.registerTokenIfNeed(with: token)
    }
    
    private func registerTokenIfNeed(with token: String? = nil) {
        guard let token = token ?? self.subject.fcmToken.value,
              self.subject.isSignIn.value
        else { return }
        
        Task { [weak self] in
            do {
                try await self?.userNotificationUsecase.register(fcmToken: token)
                logger.log(level: .info, "register fcm token - \(token)")
            } catch {
                logger.log(level: .error, "register fcm token fail: \(error.localizedDescription)")
            }
        }
        .store(in: &self.cancellables)
    }
}


// MARK: - 푸시 수신

extension ApplicationRootViewModelImple {

    func handleReceivePushNotification(userInfo: [AnyHashable: Any]) {

        // AI job 상태 변경 — data.jobId로 식별 (서버 aiFront 스펙)
        if let jobId = userInfo["jobId"] as? String {
            self.aiJobRefreshUsecase.handleJobStatusChanged(jobId)
            return
        }

        // 그 외 푸시(이벤트 리마인더 등)는 현재 앱에서 별도 처리 없음 — 표시만 된다.
    }
}
