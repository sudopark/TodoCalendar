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
    private var spyFirebaseAuthService: StubFirebaseAuthService!
    
    override func setUpWithError() throws {
        self.spyKeyChainStore = .init()
        self.stubRemote = .init(responses: self.responses)
        self.spyFirebaseAuthService = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyKeyChainStore = nil
        self.stubRemote = nil
    }
    
    private func makeRepository(shouldFail: Bool = false) -> AuthRepositoryImple {
        self.spyFirebaseAuthService.shouldFail = shouldFail
        
        return AuthRepositoryImple(
            remoteAPI: self.stubRemote,
            authStore: self.spyKeyChainStore,
            keyChainStorage: self.spyKeyChainStore,
            firebaseAuthService: spyFirebaseAuthService
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
    
    func testRepository_signInApple() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let credential = AppleOAuth2Credential(provider: "apple", idToken: "token", nonce: "nonce")
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
        let credentialBeforeSignIn = self.stubRemote.credential
        
        let credential = GoogleOAuth2Credential(idToken: "some", accessToken: "token")
        let _ = try? await repository.signIn(credential)
        
        let authAfterSignIn = try? await repository.loadLatestSignInAuth()
        let credentialAfterSignIn = self.stubRemote.credential
        // then
        XCTAssertNil(authBeforeSignIn)
        XCTAssertNil(credentialBeforeSignIn)
        XCTAssertNotNil(authAfterSignIn)
        XCTAssertNotNil(credentialAfterSignIn)
    }
    
    func testRepository_signOut() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        try await repository.signOut()
        
        // then
        let authAfterSignIn = try? await repository.loadLatestSignInAuth()
        XCTAssertEqual(self.spyFirebaseAuthService.didSignout, true)
        XCTAssertNil(authAfterSignIn)
        XCTAssertNil(self.stubRemote.credential)
    }
}


class StubFirebaseAuthService: FirebaseAuthService {
    
    func setup() throws { }
    
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
    
    var shouldFailRefresh: Bool = false
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        if self.shouldFailRefresh {
            resultHandler(.failure(RuntimeError("failed")))
        } else {
            let result = AuthRefreshResult(uid: "uid", idToken: "access-new", refreshToken: "refresh-new")
            resultHandler(.success(result))
        }
    }
    
    var didSignout: Bool?
    func signOut() throws {
        self.didSignout = true
    }
}


class SpyKeyChainStorage: KeyChainStorage, AuthStore, @unchecked Sendable {
    
    private var storage: [String: any Codable] = [:]
    
    func setupSharedGroup(_ identifier: String) {}
    
    func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key] as? T
    }
    
    func loadCurrentAuth() -> Domain.Auth? {
        let mapper: AuthMapper? = self.load("current_auth")
        return mapper?.auth
    }
    
    func updateAuth(_ auth: Domain.Auth) {
        let mapper = AuthMapper(auth: auth)
        self.update("current_auth", mapper)
    }
    
    func update<T>(_ key: String, _ value: T) where T : Encodable {
        self.storage[key] = value as? Codable
    }
    
    func remove(_ key: String) {
        self.storage[key] = nil
    }
    
    func removeAuth() {
        self.storage.removeValue(forKey: "current_auth")
    }
}

extension AuthRepositoryImpleTests {
    
    private var responses: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                method: .put,
                endpoint: AccountAPIEndpoints.info,
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
