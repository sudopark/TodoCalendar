//
//  GoogleOAuth2ServiceUsecaseImple.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import Extensions


public final class GoogleOAuth2ServiceUsecaseImple: OAuth2ServiceUsecase, @unchecked Sendable {
    
    private let topViewControllerFinding: () -> UIViewController?
    public init(topViewControllerFinding: @escaping () -> UIViewController?) {
        self.topViewControllerFinding = topViewControllerFinding
    }
}

extension GoogleOAuth2ServiceUsecaseImple {
    
    @MainActor
    public func requestAuthentication() async throws -> OAuth2Credential {
        guard let topViewController = self.topViewControllerFinding()
        else {
            throw RuntimeError(key: "GoogleSignIn_oauth_fail", "top viewController not found")
        }
        
        guard let clientId = FirebaseApp.app()?.options.clientID else {
            throw RuntimeError(key: "GoogleSignIn_oauth_fail", "firebase clientId not exists")
        }
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topViewController)
        
        guard let idToken = result.user.idToken?.tokenString
        else {
            throw RuntimeError(key: "GoogleSignIn_oauth_fail", "fail to get idToken from google signin result")
        }
        
        return GoogleOAuth2Credential(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }
    
    public func handle(open url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
