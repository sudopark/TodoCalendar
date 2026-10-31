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

public protocol FirebaseAuthService {
    
    func setup() throws
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult
    
    func signOut() throws
    
    func deleteAccount() async throws
}
