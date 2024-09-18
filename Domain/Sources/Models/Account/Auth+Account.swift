//
//  Auth.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public struct Auth: Sendable {
    
    public let uid: String
    public let accessToken: String
    public var refreshToken: String?

    public init(
        uid: String,
        accessToken: String,
        refreshToken: String? = nil
    ) {
        self.uid = uid
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}


public struct AccountInfo: Sendable {
    
    public let userId: String
    public var email: String?
    public var signInMethod: String?
    
    public var firstSignIn: TimeInterval?
    public var lastSignIn: TimeInterval?
    
    public init(_ userId: String) {
        self.userId = userId
    }
}


public struct Account: Sendable {
    
    public let auth: Auth
    public let info: AccountInfo
    
    public init(auth: Auth, info: AccountInfo) {
        self.auth = auth
        self.info = info
    }
}
