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
    
}

public struct AppleOAuth2ServiceProvider: OAuth2ServiceProvider { 
    public init() { }
}

public struct GoogleOAuth2ServiceProvider: OAuth2ServiceProvider {
    public init() { }
}


// MARK: - Credential

public protocol OAuth2Credential: Sendable { }

public struct AppleOAuth2Credential: OAuth2Credential {
    
    public let provider: String
    public let idToken: String
    public let nonce: String
    public var accessToken: String?
    
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
    
    public init(
        idToken: String,
        accessToken: String
    ) {
        self.idToken = idToken
        self.accessToken = accessToken
    }
}
