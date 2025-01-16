//
//  AuthRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import FirebaseAuth
import Domain
import Extensions


// MARK: - firebase auth service

public protocol FirebaseAuthDataResult {
    
    var uid: String { get }
    func idTokenWithoutRefreshing() async throws -> String
    var refreshToken: String? { get }
}

extension AuthDataResult: FirebaseAuthDataResult {
    public var uid: String {
        return self.user.uid
    }
    
    public func idTokenWithoutRefreshing() async throws -> String {
        return try await self.user.idTokenForcingRefresh(false)
    }
    
    public var refreshToken: String? {
        return self.user.refreshToken
    }
}

public struct AuthRefreshResult {
    let uid: String
    let idToken: String
    let refreshToken: String?
    
    init(uid: String, idToken: String, refreshToken: String?) {
        self.uid = uid
        self.idToken = idToken
        self.refreshToken = refreshToken
    }
}

public protocol FirebaseAuthService {
    
    func setup() throws
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult
    
    func refreshToken(
        _ resultHandler: @escaping (Result<AuthRefreshResult, any Error>) -> Void
    )
    
    func signOut() throws
    
    func deleteAccount() async throws
}


public final class FirebaseAuthServiceImple: FirebaseAuthService {
    
    private let appGroupId: String
    public init(appGroupId: String, useEmulator: Bool = false) {
        self.appGroupId = appGroupId
        if useEmulator {
            Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        }
    }
    
    public func setup() throws {
        try Auth.auth().useUserAccessGroup(self.appGroupId)
    }
    
    public func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        
        switch credential {
        case let googleCredential as GoogleOAuth2Credential:
            let credential = GoogleAuthProvider.credential(
                withIDToken: googleCredential.idToken,
                accessToken: googleCredential.accessToken
            )
            return try await Auth.auth().signIn(with: credential)
            
        case let appleCredential as AppleOAuth2Credential:
            let credential = OAuthProvider.credential(
                withProviderID: appleCredential.provider,
                idToken: appleCredential.idToken,
                rawNonce: appleCredential.nonce
            )
            return try await Auth.auth().signIn(with: credential)
            
        default:
            throw RuntimeError("not support signin credential")
        }
    }
    
    public func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, any Error>) -> Void) {
        
        guard let currentUser = Auth.auth().currentUser
        else {
            resultHandler(.failure(RuntimeError("not current user")))
            return
        }
        
        currentUser.getIDTokenResult(forcingRefresh: true) { result, error in
            guard let result = result, error == nil
            else {
                let error = error ?? RuntimeError("refresh failed")
                resultHandler(.failure(error))
                return
            }
            let refreshResult = AuthRefreshResult(
                uid: currentUser.uid,
                idToken: result.token,
                refreshToken: Auth.auth().currentUser?.refreshToken
            )
            resultHandler(.success(refreshResult))
        }
    }
    
    public func signOut() throws {
        try Auth.auth().signOut()
    }
    
    public func deleteAccount() async throws {
        guard let auth = Auth.auth().currentUser else { return }
        try await auth.delete()
    }
}


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
    
    
    private func authorize(_ credential: OAuth2Credential) async throws -> Domain.Auth {
        
        let result = try await self.firebaseAuthService.authorize(with: credential)
        let accessToken = try await result.idTokenWithoutRefreshing()
        
        return .init(
            uid: result.uid,
            accessToken: accessToken,
            refreshToken: result.refreshToken
        )
    }
    
    private func postSignInAction(_ auth: Domain.Auth) async throws -> Account {
        let info = try await self.loadAccountInfo(auth)
        self.authStore.saveAuth(auth)
        self.keyChainStorage.update(accountInfoKey, AccountInfoMapper(info: info))
        self.remoteAPI.setup(credential: .init(auth: auth))
        return .init(auth: auth, info: info)
    }
    
    private func loadAccountInfo(_ auth: Domain.Auth) async throws -> AccountInfo {
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
