//
//  AccountUsecaseImple.swift
//  Domain
//
//  Created by sudo.park on 2/25/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


public final class AccountUsecaseImple: @unchecked Sendable {
    
    private let oauth2ServiceProvider: any OAuth2ServiceUsecaseProvider
    private let authRepository: any AuthRepository
    private let sharedStore: SharedDataStore
    private var lastestUsedOAuthUsecase: (any OAuth2ServiceUsecase)?
    private let accountChangedEventSubject = PassthroughSubject<AccountChangedEvent, Never>()
    
    public init(
        oauth2ServiceProvider: any OAuth2ServiceUsecaseProvider,
        authRepository: any AuthRepository,
        sharedStore: SharedDataStore
    ) {
        self.oauth2ServiceProvider = oauth2ServiceProvider
        self.authRepository = authRepository
        self.sharedStore = sharedStore
    }
}


// MARK: - AccountUsecaseImple + AuthUsecase

extension AccountUsecaseImple: AuthUsecase {
    
    public func signIn(_ provider: any OAuth2ServiceProvider) async throws -> Account {
        guard let usecase = self.oauth2ServiceProvider.usecase(for: provider)
        else {
            throw RuntimeError("not support oauth service for provider: \(provider)")
        }
        self.lastestUsedOAuthUsecase = usecase
        let credential = try await usecase.requestAuthentication()
        
        let account = try await self.authRepository.signIn(credential)
        self.setupAccount(account)
        self.accountChangedEventSubject.send(.signedIn(account))
        return account
    }
    
    public func signOut() async throws {
        try await self.authRepository.signOut()
        self.setupAccount(nil)
        self.accountChangedEventSubject.send(.signOut)
    }
    
    public var supportOAuth2Service: [OAuth2ServiceProvider] {
        return self.oauth2ServiceProvider.supportOAuth2Service
    }
    
    public func handleAuthenticationResultOrNot(open url: URL) -> Bool {
     
        if self.lastestUsedOAuthUsecase?.handle(open: url) == true {
            return true
        }
        
        return false
    }
}


// MARK: - AccountUsecaseImple + AccountUsecase

extension AccountUsecaseImple: AccountUsecase {
    
    public func prepareLastSignInAccount() async throws -> Account? {
        let account = try await self.authRepository.loadLatestSignInAuth()
        self.setupAccount(account)
        return account
    }
    
    public var currentAccountInfo: AnyPublisher<AccountInfo?, Never> {
        return self.sharedStore
            .observe(AccountInfo.self, key: self.accountShareKey)
            .eraseToAnyPublisher()
    }
    
    public var accountStatusChanged: AnyPublisher<AccountChangedEvent, Never> {
        return self.accountChangedEventSubject
            .eraseToAnyPublisher()
    }
    
    private var accountShareKey: String {
        return ShareDataKeys.accountInfo.rawValue
    }
    
    private func setupAccount(_ account: Account?) {
        if let info = account?.info {
            self.sharedStore.put(AccountInfo.self, key: self.accountShareKey, info)
        } else {
            self.sharedStore.delete(self.accountShareKey)
        }
    }
}
