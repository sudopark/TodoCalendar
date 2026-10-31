//
//  AuthRepositoryImpleTests.swift
//  AccountDomainTests
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import FirebaseAuth
import Extensions
import UnitTestHelpKit
import RemoteInfraInterface
import RemoteInfraTesting
import StorageInfraTesting
import AccountDomainTesting
@testable import AccountDomain
@testable import AccountDomainInterface



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
            authStore: AuthStoreImple(
                keyChainStorage: self.spyKeyChainStore,
                environmentStorage: FakeEnvironmentStorage()
            ),
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
        let credential = GoogleOAuth2Credential(idToken: "some", accessToken: "token", refreshToken: "refresh")
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
            let credential = GoogleOAuth2Credential(idToken: "some", accessToken: "token", refreshToken: "refresh")
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
        
        let credential = GoogleOAuth2Credential(idToken: "some", accessToken: "token", refreshToken: "refresh")
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
        let authAfterSignout = try? await repository.loadLatestSignInAuth()
        XCTAssertEqual(self.spyFirebaseAuthService.didSignout, true)
        XCTAssertNil(authAfterSignout)
        XCTAssertNil(self.stubRemote.credential)
    }
    
    func testRepository_deleteAccount() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        try await repository.deleteAccount()
        
        // then
        let authAfterDelete = try? await repository.loadLatestSignInAuth()
        XCTAssertEqual(self.spyFirebaseAuthService.didDelete, true)
        XCTAssertNil(authAfterDelete)
        XCTAssertNil(self.stubRemote.credential)
    }
}


extension AuthRepositoryImpleTests {
    
    private var responses: [StubRemoteAPI.Response] {
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
                )),
            .init(
                method: .delete,
                endpoint: AccountAPIEndpoints.account,
                resultJsonString: .success(
                    """
                    { "status": "ok" }
                    """
                )
            )
        ]
    }
}
