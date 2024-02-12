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

public protocol FirebaseAuthService {
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult
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
}


// MARK: - AuthRepositoryImple

public final class AuthRepositoryImple: AuthRepository, @unchecked Sendable {
    
    private let keyChainStorage: any KeyChainStorage
    private let firebaseAuthService: any FirebaseAuthService
    
    public init(
        keyChainStorage: any KeyChainStorage,
        firebaseAuthService: (any FirebaseAuthService)? = nil
    ) {
        self.keyChainStorage = keyChainStorage
        self.firebaseAuthService = firebaseAuthService ?? Auth.auth()
    }
}


extension AuthRepositoryImple {
    
    private var latestAuthKey: String { "current_auth" }
    
    public func loadLatestSignInAuth() async throws -> Domain.Auth? {
        guard let mapper: AuthMapper = self.keyChainStorage.load(latestAuthKey)
        else {
            return nil
        }
        return mapper.auth
    }
    
    public func signIn(_ credential: OAuth2Credential) async throws -> Domain.Auth {
        switch credential {
        case let googleCredential as GoogleOAuth2Credential:
            let auth = try await googleSignIn(googleCredential)
            try await self.postSignInAction(auth)
            return auth
            
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
    
    private func postSignInAction(_ auth: Domain.Auth) async throws {
        // TODO: run post actions
        self.keyChainStorage.update(latestAuthKey, AuthMapper(auth: auth))
    }
}
