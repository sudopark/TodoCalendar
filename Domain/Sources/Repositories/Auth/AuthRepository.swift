//
//  AuthRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation


public protocol AuthRepository: Sendable {
    
    func loadLatestSignInAuth() async throws -> Account?
    func signIn(_ credential: any OAuth2Credential) async throws -> Account
    func signOut() async throws
    func deleteAccount() async throws
}
