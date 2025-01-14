//
//  OAuth2ServiceUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import UIKit


public protocol OAuth2ServiceUsecase: Sendable {
    
    associatedtype CredentialType: OAuth2Credential
    
    @MainActor
    func requestAuthentication() async throws -> CredentialType
    
    func handle(open url: URL) -> Bool
}


public protocol OAuth2ServiceUsecaseProvider: Sendable {
    
    func usecase(for provider: any OAuth2ServiceProvider) -> (any OAuth2ServiceUsecase)?
    var supportOAuth2Service: [any OAuth2ServiceProvider] { get }
}


public final class OAuth2ServiceUsecaseProviderImple: OAuth2ServiceUsecaseProvider, @unchecked Sendable {
    
    private let topViewControllerFinding: () -> UIViewController?
    public init(topViewControllerFinding: @escaping () -> UIViewController?) {
        self.topViewControllerFinding = topViewControllerFinding
    }
    
    public func usecase(
        for provider: any OAuth2ServiceProvider
    ) -> (any OAuth2ServiceUsecase)? {
        
        switch provider {
        case let google as GoogleOAuth2ServiceProvider:
            return GoogleOAuth2ServiceUsecaseImple(
                additionalScope: google.scopes,
                topViewControllerFinding: self.topViewControllerFinding
            )
            
        case let apple as AppleOAuth2ServiceProvider:
            return AppleOAuth2ServiceUsecaseImple(
                preHandleResult: apple.appleSignInResult
            )
            
        default:
            return nil
        }
    }
    
    public var supportOAuth2Service: [any OAuth2ServiceProvider] {
        return [
            GoogleOAuth2ServiceProvider(),
            AppleOAuth2ServiceProvider()
        ]
    }
}
