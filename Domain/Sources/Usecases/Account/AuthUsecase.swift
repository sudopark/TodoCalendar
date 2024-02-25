//
//  AuthUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions

public protocol AuthUsecase: Sendable {
    
    func signIn(_ provider: any OAuth2ServiceProvider) async throws -> Account
    func handleAuthenticationResultOrNot(open url: URL) ->Bool
    
    var supportOAuth2Service: [any OAuth2ServiceProvider] { get }
}
