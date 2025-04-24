//
//  ExternalServiceAccountinfo.swift
//  Domain
//
//  Created by sudo.park on 1/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public struct ExternalServiceAccountinfo: Sendable, Equatable {
    
    public let serviceIdentifier: String
    public var email: String?
    public init(
        _ serviceIdentifier: String,
        email: String? = nil
    ) {
        self.serviceIdentifier = serviceIdentifier
        self.email = email
    }
}
