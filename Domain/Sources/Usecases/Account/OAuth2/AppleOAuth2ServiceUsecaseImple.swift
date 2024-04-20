//
//  AppleOAuth2ServiceUsecaseImple.swift
//  Domain
//
//  Created by sudo.park on 4/17/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions


public final class AppleOAuth2ServiceUsecaseImple: OAuth2ServiceUsecase, @unchecked Sendable {
    
    private let preHandleResult: Result<AppleOAuth2ServiceProvider.AppleLoginIDTokenWithMetaData, any Error>?
    init(
        preHandleResult: Result<AppleOAuth2ServiceProvider.AppleLoginIDTokenWithMetaData, any Error>?
    ) {
        self.preHandleResult = preHandleResult
    }
}


extension AppleOAuth2ServiceUsecaseImple {
    
    @MainActor
    public func requestAuthentication() async throws -> any OAuth2Credential {
        switch self.preHandleResult {
        case .success(let data):
            let credential = AppleOAuth2Credential(
                provider: "apple.com",
                idToken: data.appleIDToken,
                nonce: data.nonce
            )
            return credential
            
        case .failure(let error):
            throw error
        case .none:
            throw RuntimeError("apple login not handled")
        }
    }
    
    public func handle(open url: URL) -> Bool {
        return false
    }
}
