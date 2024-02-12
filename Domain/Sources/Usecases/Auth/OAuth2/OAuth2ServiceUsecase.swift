//
//  OAuth2ServiceUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import UIKit


public protocol OAuth2ServiceUsecase: Sendable {
    
    var provider: any OAuth2ServiceProvider { get }
    
    func requestAuthentication() async throws -> any OAuth2Credential
    
    func handle(open url: URL) -> Bool
}


public protocol OAuth2ServiceUsecaseProvider: Sendable {
    
    func usecase(for provider: any OAuth2ServiceProvider) -> (any OAuth2ServiceUsecase)?
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
        case is GoogleOAuth2ServiceProvider:
            return GoogleOAuth2ServiceUsecaseImple(
                topViewControllerFinding: self.topViewControllerFinding
            )
            
        default:
            return nil
        }
    }
}
