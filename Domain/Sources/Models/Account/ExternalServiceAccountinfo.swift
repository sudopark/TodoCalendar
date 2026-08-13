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
    public var intergrationTime: Date?
    public var grantedScopes: [String]?

    public init(
        _ serviceIdentifier: String,
        email: String? = nil
    ) {
        self.serviceIdentifier = serviceIdentifier
        self.email = email
    }

    public var canWriteGoogleCalendar: Bool {
        guard self.serviceIdentifier == GoogleCalendarService.id,
              let scopes = self.grantedScopes
        else { return false }
        return scopes.contains(GoogleCalendarService.Scope.readWrite.rawValue)
    }
}
