//
//  Auth+Mapping.swift
//  Repository
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


struct AuthMapper: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case uid
        case access_token
        case refresh_token
    }
    
    let auth: Auth
    
    init(auth: Auth) {
        self.auth = auth
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            auth: .init(
                uid: try container.decode(String.self, forKey: .uid),
                accessToken: try container.decode(String.self, forKey: .access_token),
                refreshToken: try container.decode(String.self, forKey: .refresh_token)
            )
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.auth.uid, forKey: .uid)
        try container.encode(self.auth.accessToken, forKey: .access_token)
        try container.encode(self.auth.refreshToken, forKey: .refresh_token)
    }
}
