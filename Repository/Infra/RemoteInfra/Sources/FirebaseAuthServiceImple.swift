//
//  FirebaseAuthServiceImple.swift
//  RemoteInfra
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import FirebaseAuth
import Extensions
import RemoteInfraInterface
import AccountDomainInterface


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
