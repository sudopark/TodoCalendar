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


final class ApplicationRootViewModelImple: @unchecked Sendable {
 
    private let authUsecase: any AuthUsecase
    private let accountUsecase: any AccountUsecase
    private let prepareLaunchUsecase: any ApplicationPrepareLaunchUsecase
    var router: ApplicationRootRouter?
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        prepareLaunchUsecase: any ApplicationPrepareLaunchUsecase
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.prepareLaunchUsecase = prepareLaunchUsecase
        
        self.bindAccountStatusChanged()
    }
}


// MARK: - handle root routing

extension ApplicationRootViewModelImple: OAuthAutenticatorTokenRefreshListener {
    
    func prepareInitialScene() {
        Task {
            let result = try await self.prepareLaunchUsecase.prepareLaunch()
            self.router?.setupInitialScene(result)
        }
    }
    
    private func bindAccountStatusChanged() {
        
        self.accountUsecase.accountStatusChanged
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] status in
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
        // TODO: replace database
        self.router?.changeRootSceneAfter(signIn: account.auth)
    }
    
    private func handleUserSignedOut() {
        // TODO: replace database
        self.router?.changeRootSceneAfter(signIn: nil)
    }
    
    func oauthAutenticator(didRefresh auth: Auth) {
        // TODO: replace database
        self.router?.changeRootSceneAfter(signIn: auth)
    }
    
    func oauthAutenticator(didRefreshFailed error: Error) {
        // TODO: replace database
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

