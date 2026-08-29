//
//  GoogleOAuth2ServiceUsecaseImple.swift
//  AuthService
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import UIKit
import Prelude
import Optics
import FirebaseCore
import FirebaseAuth
@preconcurrency import GoogleSignIn
import Domain
import Extensions


public final class GoogleOAuth2ServiceUsecaseImple: OAuth2ServiceUsecase, @unchecked Sendable {
    
    public typealias CredentialType = GoogleOAuth2Credential
    
    private let additionalScope: [String]?
    private let topViewControllerFinding: () -> UIViewController?
    public init(
        additionalScope: [String]?,
        topViewControllerFinding: @escaping () -> UIViewController?
    ) {
        self.additionalScope = additionalScope
        self.topViewControllerFinding = topViewControllerFinding
    }
}

extension GoogleOAuth2ServiceUsecaseImple {
    
    @MainActor
    public func requestAuthentication() async throws -> GoogleOAuth2Credential {
        return try await self.requestAuthentication(hint: nil)
    }

    @MainActor
    public func requestAuthentication(hint: String?) async throws -> GoogleOAuth2Credential {
        guard let topViewController = self.topViewControllerFinding()
        else {
            throw RuntimeError(key: "GoogleSignIn_oauth_fail", "top viewController not found")
        }

        guard let clientId = FirebaseApp.app()?.options.clientID else {
            throw RuntimeError(key: "GoogleSignIn_oauth_fail", "firebase clientId not exists")
        }

        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: topViewController,
            hint: hint,
            additionalScopes: self.additionalScope
        )
        
        guard let idToken = result.user.idToken?.tokenString
        else {
            throw RuntimeError(key: "GoogleSignIn_oauth_fail", "fail to get idToken from google signin result")
        }
        
        return GoogleOAuth2Credential(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString,
            refreshToken: result.user.refreshToken.tokenString
        )
        |> \.accessTokenExpirationDate .~ result.user.accessToken.expirationDate
        |> \.refreshTokenExpirationDate .~ result.user.refreshToken.expirationDate
        |> \.email .~ result.user.profile?.email
        |> \.grantedScopes .~ result.user.grantedScopes
    }
    
    public func handle(open url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
