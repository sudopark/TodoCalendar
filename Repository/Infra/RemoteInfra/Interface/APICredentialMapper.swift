//
//  APICredentialMapper.swift
//  RemoteInfraInterface
//
//  Created by sudo.park on 1/22/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import RemoteInfraInterface

public struct APICredentialMapper: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case accesTokenExpirationDate
        case refreshTokenExpirationDate
    }
    
    public let credential: APICredential
    public init(credential: APICredential) {
        self.credential = credential
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var credential = APICredential(
            accessToken: try container.decode(String.self, forKey: .accessToken)
        )
        credential.refreshToken = try? container.decode(String.self, forKey: .refreshToken)
        credential.accessTokenExpirationDate = (try? container.decode(TimeInterval.self, forKey: .accesTokenExpirationDate))
            .map { Date(timeIntervalSince1970: $0) }
        credential.refreshTokenExpirationDate = (try? container.decode(TimeInterval.self, forKey: .refreshTokenExpirationDate))
            .map { Date(timeIntervalSince1970: $0) }
        self.credential = credential
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.credential.accessToken, forKey: .accessToken)
        try container.encodeIfPresent(self.credential.refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(
            self.credential.accessTokenExpirationDate?.timeIntervalSince1970, forKey: .accesTokenExpirationDate
        )
        try container.encodeIfPresent(
            self.credential.refreshTokenExpirationDate?.timeIntervalSince1970, forKey: .refreshTokenExpirationDate
        )
    }
}
