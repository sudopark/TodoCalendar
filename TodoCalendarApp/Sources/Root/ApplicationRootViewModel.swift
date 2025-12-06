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
    private let externalCalendarServiceUsecase: any ExternalCalendarIntegrationUsecase
    private let userNotificationUsecase: any UserNotificationUsecase
    private let environmentStorage: any EnvironmentStorage
    var router: ApplicationRootRouter?
    
    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        prepareUsecase: any ApplicationPrepareUsecase,
        externalCalendarServiceUsecase: any ExternalCalendarIntegrationUsecase,
        userNotificationUsecase: any UserNotificationUsecase,
        environmentStorage: any EnvironmentStorage
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.prepareUsecase = prepareUsecase
        self.externalCalendarServiceUsecase = externalCalendarServiceUsecase
        self.userNotificationUsecase = userNotificationUsecase
        self.environmentStorage = environmentStorage
        
        self.bindAccountStatusChanged()
        self.bindApplicationStatusChanged()
        self.bindExternalCalenarIntegratedStatus()
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
    
    func prepareInitialScene() {
        Task {
            let result = try await self.prepareUsecase.prepareLaunch()
            self.router?.setupInitialScene(result)
            self.subject.isSignIn.send(result.latestLoginAcount != nil)
            self.registerTokenIfNeed()
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
                if status.account != nil {
                    self?.prepareUsecase.prepareExternalCalendarIntegrated(status.serviceId)
                } else {
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
    }
    
    private func handleDidEnterBackground() {
        self.environmentStorage.update(
            EnvironmentKeys.needCheckResetWidgetCache.rawValue,
            true
        )
        self.environmentStorage.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
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
