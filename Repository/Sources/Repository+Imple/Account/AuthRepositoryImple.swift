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
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult
    
    func refreshToken(
        _ resultHandler: @escaping (Result<AuthRefreshResult, any Error>) -> Void
    )
    
    func signOut() throws
}

extension FirebaseAuth.Auth: FirebaseAuthService { 
    
    public func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        switch credential {
        case let googleCredential as GoogleOAuth2Credential:
            let credential = GoogleAuthProvider.credential(
                withIDToken: googleCredential.idToken,
                accessToken: googleCredential.accessToken
            )
            return try await self.signIn(with: credential)
            
        default:
            throw RuntimeError("not support signin credential")
        }
    }
    
    public func refreshToken(
        _ resultHandler: @escaping (Result<AuthRefreshResult, any Error>) -> Void
    ) {
        guard let currentUser = self.currentUser
        else {
            resultHandler(.failure(RuntimeError("not current user")))
            return
        }
        
        currentUser.getIDTokenResult(forcingRefresh: true) { [weak self] result, error in
            guard let result = result, error == nil
            else {
                return
            }
            let refreshResult = AuthRefreshResult(
                uid: currentUser.uid,
                idToken: result.token,
                refreshToken: self?.currentUser?.refreshToken
            )
            resultHandler(.success(refreshResult))
        }
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
        guard let auth = self.authStore.loadCurrentAuth(),
              let infoMapper: AccountInfoMapper = self.keyChainStorage.load(accountInfoKey)
        else {
            return nil
        }
        self.remoteAPI.setup(credential: auth)
        return .init(auth: auth, info: infoMapper.info)
    }
    
    public func signIn(_ credential: OAuth2Credential) async throws -> Account {
        
        // TODO: signIn 이전에 로그인된 계정 있으면 로그아웃 처리 필요
        
        switch credential {
        case let googleCredential as GoogleOAuth2Credential:
            let auth = try await googleSignIn(googleCredential)
            let account = try await self.postSignInAction(auth)
            return account
            
        default:
            throw RuntimeError("not support signin credential")
        }
    }
    
    
    private func googleSignIn(_ googleCredential: GoogleOAuth2Credential) async throws -> Domain.Auth {
        
        let result = try await self.firebaseAuthService.authorize(with: googleCredential)
        let accessToken = try await result.idTokenWithoutRefreshing()
        
        return .init(
            uid: result.uid,
            accessToken: accessToken,
            refreshToken: result.refreshToken
        )
    }
    
    private func postSignInAction(_ auth: Domain.Auth) async throws -> Account {
        let info = try await self.loadAccountInfo(auth)
        self.authStore.updateAuth(auth)
        self.keyChainStorage.update(accountInfoKey, AccountInfoMapper(info: info))
        self.remoteAPI.setup(credential: auth)
        return .init(auth: auth, info: info)
    }
    
    private func loadAccountInfo(_ auth: Domain.Auth) async throws -> AccountInfo {
        let infoDTO: AccountInfoMapper = try await self.remoteAPI.request(
            .put, AccountAPIEndpoints.info,
            with: ["Authorization": "Bearer \(auth.accessToken)"]
        )
        return infoDTO.info
    }
}
