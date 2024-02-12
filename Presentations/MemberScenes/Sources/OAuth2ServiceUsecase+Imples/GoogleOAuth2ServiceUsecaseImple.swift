//
//  GoogleOAuth2ServiceUsecaseImple.swift
//  MemberScenes
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import UIKit
import GoogleSignIn
import Domain
import Extensions


final class GoogleOAuth2ServiceUsecaseImple: OAuth2ServiceUsecase {
    
    var provider: any OAuth2ServiceProvider { GoogleOAuth2ServiceProvider() }
}

extension GoogleOAuth2ServiceUsecaseImple {
    
    func signIn() async throws -> any OAuth2Credential {
       throw RuntimeError("not implemented")
    }
}
