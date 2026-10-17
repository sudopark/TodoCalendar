//
//  DummyFirebaseAuthService.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2026/09/09.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import Repository


// MARK: - DummyFirebaseAuthService

// 격리 실행에서 Firebase SDK 를 아예 띄우지 않으려고 계약만 만족시킨다
final class DummyFirebaseAuthService: FirebaseAuthService {
    
    func setup() throws { }
    
    func signOut() throws { }
    
    func deleteAccount() async throws { }
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        throw RuntimeError("failed")
    }
    
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) { }
}
