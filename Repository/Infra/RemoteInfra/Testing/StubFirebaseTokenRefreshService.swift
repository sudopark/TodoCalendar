//
//  StubFirebaseTokenRefreshService.swift
//  RemoteInfraTesting
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface


public class StubFirebaseTokenRefreshService: FirebaseTokenRefreshService {

    public init() { }
    
    public var refreshFailError: (any Error)?
    public func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        if let refreshFailError = self.refreshFailError {
            resultHandler(.failure(refreshFailError))
        } else {
            let result = AuthRefreshResult(uid: "uid", idToken: "access-new", refreshToken: "refresh-new")
            resultHandler(.success(result))
        }
    }
    
    public var didSignout: Bool?
    public func signOut() throws {
        self.didSignout = true
    }
}
