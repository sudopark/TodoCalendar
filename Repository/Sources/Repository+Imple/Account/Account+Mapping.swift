//
//  Auth+Mapping.swift
//  Repository
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


private enum CodingKeys: String, CodingKey {
    case auth
    case info
    case uid
    case access_token
    case refresh_token
    case email
    case method
    case firstSignedIn = "first_signed_in"
    case lastSignedIn = "last_sign_in"
}

struct AuthMapper: Codable {
    
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

struct AccountInfoMapper: Codable {
    
    let info: AccountInfo
    
    init(info: AccountInfo) {
        self.info = info
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let info = AccountInfo(try container.decode(String.self, forKey: .uid))
        |> \.email .~ (try? container.decode(String.self, forKey: .email))
        |> \.signInMethod .~ (try? container.decode(String.self, forKey: .method))
        |> \.firstSignIn .~ (try? container.decode(Double.self, forKey: .firstSignedIn))
        |> \.lastSignIn .~ (try? container.decode(Double.self, forKey: .lastSignedIn))
        self.init(info: info)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.info.userId, forKey: .uid)
        try? container.encode(self.info.email, forKey: .email)
        try? container.encode(self.info.signInMethod, forKey: .method)
        try? container.encode(self.info.firstSignIn, forKey: .firstSignedIn)
        try? container.encode(self.info.lastSignIn, forKey: .lastSignedIn)
    }
}

struct AccountMapper: Decodable {
    
    let account: Account
    init(account: Account) {
        self.account = account
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let authContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .auth)
        let auth = try authContainer.decode(AuthMapper.self, forKey: .auth)
        
        let infoContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .info)
        let info = try infoContainer.decode(AccountInfoMapper.self, forKey: .info)
        
        self.init(
            account: .init(auth: auth.auth, info: info.info)
        )
    }
}
