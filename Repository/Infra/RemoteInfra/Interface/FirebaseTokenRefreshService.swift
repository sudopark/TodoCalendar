//
//  FirebaseTokenRefreshService.swift
//  RemoteInfraInterface
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct AuthRefreshResult {
    public let uid: String
    public let idToken: String
    public let refreshToken: String?
    
    public init(uid: String, idToken: String, refreshToken: String?) {
        self.uid = uid
        self.idToken = idToken
        self.refreshToken = refreshToken
    }
}

public protocol FirebaseTokenRefreshService {
    
    func refreshToken(
        _ resultHandler: @escaping (Result<AuthRefreshResult, any Error>) -> Void
    )
    
    func signOut() throws
}
