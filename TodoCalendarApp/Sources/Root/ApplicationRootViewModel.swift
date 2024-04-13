//
//  ApplicationRootViewModel.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Combine
import Domain
import Repository
import Extensions


final class ApplicationRootViewModelImple: @unchecked Sendable {
 
    private let authUsecase: any AuthUsecase
    private let accountUsecase: any AccountUsecase
    private let prepareUsecase: any ApplicationPrepareUsecase
    var router: ApplicationRootRouter?
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        prepareUsecase: any ApplicationPrepareUsecase
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.prepareUsecase = prepareUsecase
        
        self.bindAccountStatusChanged()
    }
}


// MARK: - handle root routing

extension ApplicationRootViewModelImple: OAuthAutenticatorTokenRefreshListener {
    
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
    
    private func handleUserSignedIn(_ account: Account) {
        self.prepareUsecase.prepareSignedIn(account.auth)
        self.router?.changeRootSceneAfter(signIn: account.auth)
    }
    
    private func handleUserSignedOut() {
        self.prepareUsecase.prepareSignedOut()
        self.router?.changeRootSceneAfter(signIn: nil)
    }
    
    func oauthAutenticator(didRefresh auth: Auth) {
        // do nothing
    }
    
    func oauthAutenticator(didRefreshFailed error: Error) {
        self.prepareUsecase.prepareSignedOut()
        self.router?.changeRootSceneAfter(signIn: nil)
    }
}


// MARK: - handle url

extension ApplicationRootViewModelImple {
    
    func handle(open url: URL) -> Bool {
        if self.authUsecase.handleAuthenticationResultOrNot(open: url) {
            return true
        }
        return false
    }
}

