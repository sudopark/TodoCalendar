//
//  StubFirebaseAuthService.swift
//  RemoteInfraTesting
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import RemoteInfraInterface


public class StubFirebaseAuthService: FirebaseAuthService {

    public init() { }
    
    public func setup() throws { }
    
    public struct DummyResult: FirebaseAuthDataResult {
        public var uid: String { "some" }
        
        public func idTokenWithoutRefreshing() async throws -> String {
            return "access"
        }
        
        public var refreshToken: String? { "refresh" }
    }
    
    public var shouldFail: Bool = false
    public func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        guard self.shouldFail == false
        else {
            throw RuntimeError("failed")
        }
        
        return DummyResult()
    }
    
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
    
    public var didDelete: Bool?
    public func deleteAccount() async throws {
        self.didDelete = true
    }
}
