//
//  AuthRepositoryImpleTests.swift
//  Repository
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import FirebaseAuth
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Repository


class AuthRepositoryImpleTests: BaseTestCase {
    
    private var spyKeyChainStore: SpyKeyChainStorage!
    private var stubRemote: StubRemoteAPI!
    
    override func setUpWithError() throws {
        self.spyKeyChainStore = .init()
        self.stubRemote = .init(responses: self.responses)
    }
    
    override func tearDownWithError() throws {
        self.spyKeyChainStore = nil
        self.stubRemote = nil
    }
    
    private func makeRepository(shouldFail: Bool = false) -> AuthRepositoryImple {
        let authService = StubFirebaseAuthService()
        authService.shouldFail = shouldFail
        
        return AuthRepositoryImple(
            remoteAPI: self.stubRemote,
            keyChainStorage: self.spyKeyChainStore,
            firebaseAuthService: authService
        )
    }
}

extension AuthRepositoryImpleTests {
    
    func testRepository_signInGoogle() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let credential = GoogleOAuth2Credential(idToken: "some", accessToken: "token")
        let result = try? await repository.signIn(credential)
        
        // then
        XCTAssertNotNil(result)
    }
    
    func testRepository_failSignIn() async {
        // given
        let repository = self.makeRepository(shouldFail: true)
        
        // when
        var failed: (any Error)?
        do {
            let credential = GoogleOAuth2Credential(idToken: "some", accessToken: "token")
            let _ = try await repository.signIn(credential)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testRepository_whenAfterSignIn_saveAuth() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let authBeforeSignIn = try? await repository.loadLatestSignInAuth()
        
        let credential = GoogleOAuth2Credential(idToken: "some", accessToken: "token")
        let _ = try? await repository.signIn(credential)
        
        let authAfterSignIn = try? await repository.loadLatestSignInAuth()
        
        // then
        XCTAssertNil(authBeforeSignIn)
        XCTAssertNotNil(authAfterSignIn)
    }
}


private class StubFirebaseAuthService: FirebaseAuthService {
    
    struct DummyResult: FirebaseAuthDataResult {
        var uid: String { "some" }
        
        func idTokenWithoutRefreshing() async throws -> String {
            return "access"
        }
        
        var refreshToken: String? { "refresh" }
    }
    
    var shouldFail: Bool = false
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        guard self.shouldFail == false
        else {
            throw RuntimeError("failed")
        }
        
        return DummyResult()
    }
}


class SpyKeyChainStorage: KeyChainStorage, @unchecked Sendable {
    
    private var storage: [String: any Codable] = [:]
    
    func setupSharedGroup(_ identifier: String) {}
    
    func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key] as? T
    }
    
    func update<T>(_ key: String, _ value: T) where T : Encodable {
        self.storage[key] = value as? Codable
    }
    
    func remove(_ key: String) {
        self.storage[key] = nil
    }
}

extension AuthRepositoryImpleTests {
    
    private var responses: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                endpoint: AccountAPIEndpoints.account,
                header: ["Authorization": "Bearer access"],
                resultJsonString: .success(
                """
                {
                    "uid": "some",
                    "method": "some@email.com",
                    "method": "method",
                    "first_signed_in": 0,
                    "last_signed_in": 0
                }
                """
                ))
        ]
    }
}
