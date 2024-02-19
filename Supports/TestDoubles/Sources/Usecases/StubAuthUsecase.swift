//
//  StubAuthUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


open class StubAuthUsecase: AuthUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var shouldFailSignIn: Bool = false
    open func signIn(_ provider: any OAuth2ServiceProvider) async throws -> Auth {
        guard self.shouldFailSignIn == false
        else {
            throw RuntimeError("signin failed")
        }
        
        let newAuth = Auth(uid: "id", accessToken: "access")
        return newAuth
    }
    
    open func handleAuthenticationResultOrNot(open url: URL) -> Bool {
        return true
    }
    
    public var supportOAuth2Service: [any OAuth2ServiceProvider] {
        return [GoogleOAuth2ServiceProvider()]
    }
}
