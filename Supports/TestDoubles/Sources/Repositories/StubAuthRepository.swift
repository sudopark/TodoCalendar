//
//  StubAuthRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions

open class StubAuthRepository: AuthRepository, @unchecked Sendable {
    
    private var latestAccount: Account?
    
    public init(latest: Account?) {
        self.latestAccount = latest
    }
    
    open func loadLatestSignInAuth() async throws -> Account? {
        return self.latestAccount
    }
       
    public var shouldFailSignIn: Bool = false
    open func signIn(_ credential: any OAuth2Credential) async throws -> Account {
        guard self.shouldFailSignIn == false
        else {
            throw RuntimeError("failed")
        }
        
        let newAuth = Auth(uid: "id", accessToken: "at", refreshToken: "rt")
        let account = Account(auth: newAuth, info: .init(newAuth.uid))
        self.latestAccount = account
        return account
    }
}
