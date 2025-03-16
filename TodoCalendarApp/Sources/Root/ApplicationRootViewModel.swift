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
    private let environmentStorage: any EnvironmentStorage
    var router: ApplicationRootRouter?
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        prepareUsecase: any ApplicationPrepareUsecase,
        externalCalendarServiceUsecase: any ExternalCalendarIntegrationUsecase,
        environmentStorage: any EnvironmentStorage
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.prepareUsecase = prepareUsecase
        self.externalCalendarServiceUsecase = externalCalendarServiceUsecase
        self.environmentStorage = environmentStorage
        
        self.bindAccountStatusChanged()
        self.bindApplicationStatusChanged()
        self.bindExternalCalenarIntegratedStatus()
    }
}


// MARK: - handle root routing

extension ApplicationRootViewModelImple: AutenticatorTokenRefreshListener {
    
    func prepareInitialScene() {
        Task {
            let result = try await self.prepareUsecase.prepareLaunch()
            self.router?.setupInitialScene(result)
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
        guard FeatureFlag.isEnable(.googleCalendar) else { return }
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
        self.prepareUsecase.prepareSignedIn(account.auth)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.router?.changeRootSceneAfter(signIn: account.auth)
        }
    }
    
    private func handleUserSignedOut() {
        self.prepareUsecase.prepareSignedOut()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.router?.changeRootSceneAfter(signIn: nil)
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
            self.prepareUsecase.prepareSignedOut()
            self.router?.changeRootSceneAfter(signIn: nil)
            
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
        
        if FeatureFlag.isEnable(.googleCalendar) && self.externalCalendarServiceUsecase.handleAuthenticationResultOrNot(open: url) {
            return true
        }
        
        if self.authUsecase.handleAuthenticationResultOrNot(open: url) {
            return true
        }
        return false
    }
}

