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
