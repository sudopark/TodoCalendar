//
//  ExternalServiceAccount+Mapping.swift
//  ExternalCalendarDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import RemoteInfraInterface
import ExternalCalendarDomainInterface


// MARK: - External Account

struct ExternalServiceAccountMapper: Codable {
    
    let account: ExternalServiceAccountinfo
    
    private enum CodingKeys: String, CodingKey {
        case serviceIdentifier
        case email
        case grantedScopes
    }

    init(account: ExternalServiceAccountinfo) {
        self.account = account
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.account = ExternalServiceAccountinfo(
            try container.decode(String.self, forKey: .serviceIdentifier),
            email: try? container.decode(String.self, forKey: .email)
        )
        |> \.grantedScopes .~ (try? container.decode([String].self, forKey: .grantedScopes))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.account.serviceIdentifier, forKey: .serviceIdentifier)
        try container.encodeIfPresent(self.account.email, forKey: .email)
        try container.encodeIfPresent(self.account.grantedScopes, forKey: .grantedScopes)
    }
}
