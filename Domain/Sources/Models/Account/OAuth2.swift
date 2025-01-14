//
//  OAuth2.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - OAuth2ServiceProvider

public protocol OAuth2ServiceProvider: Sendable {
    var identifier: String { get }
}

public final class AppleOAuth2ServiceProvider: OAuth2ServiceProvider, @unchecked Sendable {
    
    public struct AppleLoginIDTokenWithMetaData {
        public let appleIDToken: String
        public let nonce: String
        public init(
            appleIDToken: String,
            nonce: String
        ) {
            self.appleIDToken = appleIDToken
            self.nonce = nonce
        }
    }
    
    public let identifier: String = "apple"
    public var appleSignInResult: Result<AppleLoginIDTokenWithMetaData, any Error>?
    public init() { }
}

public struct GoogleOAuth2ServiceProvider: OAuth2ServiceProvider {
    public let identifier: String = "google"
    public var scopes: [String]?
    public init() { }
}


// MARK: - Credential

public protocol OAuth2Credential: Sendable { }

public struct AppleOAuth2Credential: OAuth2Credential {
    
    public let provider: String
    public let idToken: String
    public let nonce: String
    
    public init(
        provider: String,
        idToken: String,
        nonce: String
    ) {
        self.provider = provider
        self.idToken = idToken
        self.nonce = nonce
    }
}

public struct GoogleOAuth2Credential: OAuth2Credential {
    
    public let idToken: String
    public let accessToken: String
    public let refreshToken: String
    public var accessTokenExpirationDate: Date?
    public var refreshTokenExpirationDate: Date?
    
    public init(
        idToken: String,
        accessToken: String,
        refreshToken: String
    ) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
