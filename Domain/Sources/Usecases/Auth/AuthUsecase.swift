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
    
    func signIn(_ provider: any OAuth2ServiceProvider) async throws -> Auth
    func handleAuthenticationResultOrNot(open url: URL) ->Bool
    
    var supportOAuth2Service: [any OAuth2ServiceProvider] { get }
}

public final class AuthUsecaseImple: AuthUsecase, @unchecked Sendable {
    
    private let oauth2ServiceProvider: any OAuth2ServiceUsecaseProvider
    private let authRepository: any AuthRepository
    private var lastestUsedOAuthUsecase: (any OAuth2ServiceUsecase)?
    
    public init(
        oauth2ServiceProvider: any OAuth2ServiceUsecaseProvider,
        authRepository: any AuthRepository
    ) {
        self.oauth2ServiceProvider = oauth2ServiceProvider
        self.authRepository = authRepository
    }
}


extension AuthUsecaseImple {
    
    public func signIn(_ provider: any OAuth2ServiceProvider) async throws -> Auth {
        guard let usecase = self.oauth2ServiceProvider.usecase(for: provider)
        else {
            throw RuntimeError("not support oauth service for provider: \(provider)")
        }
        self.lastestUsedOAuthUsecase = usecase
        let credential = try await usecase.requestAuthentication()
        
        return try await self.authRepository.signIn(credential)
    }
    
    public var supportOAuth2Service: [OAuth2ServiceProvider] {
        return self.oauth2ServiceProvider.supportOAuth2Service
    }
}

extension AuthUsecaseImple {
    
    public func handleAuthenticationResultOrNot(open url: URL) -> Bool {
     
        if self.lastestUsedOAuthUsecase?.handle(open: url) == true {
            return true
        }
        
        return false
    }
}
