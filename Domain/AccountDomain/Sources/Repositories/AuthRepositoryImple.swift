//
//  AuthRepositoryImple.swift
//  AccountDomain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions
import StorageInfraInterface
import RemoteInfraInterface
import AccountDomainInterface


// MARK: - AuthRepositoryImple

public final class AuthRepositoryImple: AuthRepository, @unchecked Sendable {
    
    private let remoteAPI: any RemoteAPI
    private let authStore: any AuthStore
    private let keyChainStorage: any KeyChainStorage
    private let firebaseAuthService: any FirebaseAuthService
    
    public init(
        remoteAPI: any RemoteAPI,
        authStore: any AuthStore,
        keyChainStorage: any KeyChainStorage,
        firebaseAuthService: any FirebaseAuthService
    ) {
        self.remoteAPI = remoteAPI
        self.authStore = authStore
        self.keyChainStorage = keyChainStorage
        self.firebaseAuthService = firebaseAuthService
    }
}


extension AuthRepositoryImple {
    
    private var accountInfoKey: String { "current_account_info" }
    
    public func loadLatestSignInAuth() async throws -> Account? {
        
        try self.firebaseAuthService.setup()
        
        guard let auth = self.authStore.loadCurrentAuth(),
              let infoMapper: AccountInfoMapper = self.keyChainStorage.load(accountInfoKey)
        else {
            self.remoteAPI.setup(credential: nil)
            return nil
        }
        self.remoteAPI.setup(credential: .init(auth: auth))
        return .init(auth: auth, info: infoMapper.info)
    }
    
    public func signIn(_ credential: OAuth2Credential) async throws -> Account {
        
        let auth = try await authorize(credential)
        let account = try await self.postSignInAction(auth)
        return account
    }
    
    
    private func authorize(_ credential: OAuth2Credential) async throws -> AccountDomainInterface.Auth {
        
        let result = try await self.firebaseAuthService.authorize(with: credential)
        let accessToken = try await result.idTokenWithoutRefreshing()
        
        return .init(
            uid: result.uid,
            accessToken: accessToken,
            refreshToken: result.refreshToken
        )
    }
    
    private func postSignInAction(_ auth: AccountDomainInterface.Auth) async throws -> Account {
        let info = try await self.loadAccountInfo(auth)
        self.authStore.saveAuth(auth)
        self.keyChainStorage.update(accountInfoKey, AccountInfoMapper(info: info))
        self.remoteAPI.setup(credential: .init(auth: auth))
        return .init(auth: auth, info: info)
    }
    
    private func loadAccountInfo(_ auth: AccountDomainInterface.Auth) async throws -> AccountInfo {
        let infoDTO: AccountInfoMapper = try await self.remoteAPI.request(
            .put, AccountAPIEndpoints.info,
            with: ["Authorization": "Bearer \(auth.accessToken)"]
        )
        return infoDTO.info
    }
    
    public func signOut() async throws {
        try self.firebaseAuthService.signOut()
        self.authStore.removeAuth()
        self.keyChainStorage.remove(accountInfoKey)
        self.remoteAPI.setup(credential: nil)
    }
    
    public func deleteAccount() async throws {
        try? await self.requestDeleteAllUserDate()
        try await self.firebaseAuthService.deleteAccount()
        self.authStore.removeAuth()
        self.keyChainStorage.remove(accountInfoKey)
        self.remoteAPI.setup(credential: nil)
    }
    
    private func requestDeleteAllUserDate() async throws {
        let endpoint: AccountAPIEndpoints = .account
        let _: AccountDeleteResultMapper = try await self.remoteAPI.request(
            .delete,
            endpoint
        )
        return
    }
}
