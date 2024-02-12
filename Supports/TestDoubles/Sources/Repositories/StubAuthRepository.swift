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
    
    private var latestAuth: Auth?
    
    public init(latest: Auth?) {
        self.latestAuth = latest
    }
    
    open func loadLatestSignInAuth() async throws -> Auth? {
        return self.latestAuth
    }
    
    public var shouldFailSignIn: Bool = false
    open func signIn(_ credential: any OAuth2Credential) async throws -> Auth {
        guard self.shouldFailSignIn == false
        else {
            throw RuntimeError("failed")
        }
        
        let newAuth = Auth(uid: "id", accessToken: "at", refreshToken: "rt")
        self.latestAuth = newAuth
        return newAuth
    }
}
