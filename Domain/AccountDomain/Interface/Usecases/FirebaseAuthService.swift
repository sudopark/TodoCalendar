//
//  FirebaseAuthService.swift
//  AccountDomainInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - firebase auth service

public protocol FirebaseAuthDataResult {
    
    var uid: String { get }
    func idTokenWithoutRefreshing() async throws -> String
    var refreshToken: String? { get }
}

public struct AuthRefreshResult {
    public let uid: String
    public let idToken: String
    public let refreshToken: String?
    
    public init(uid: String, idToken: String, refreshToken: String?) {
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
