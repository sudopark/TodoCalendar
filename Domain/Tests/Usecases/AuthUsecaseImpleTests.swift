//
//  AuthUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class AuthUsecaseImpleTests: BaseTestCase {
    
    private var dummyAuth: Auth {
        return .init(uid: "dummy", accessToken: "token", refreshToken: "refresh")
    }
    
    private func makeUsecase(
        shouldFailOAuth: Bool = false,
        shouldFailSignIn: Bool = false
    ) -> AuthUsecaseImple {
        
        let provider = FakeOAuthUsecaseProvider()
        provider.shouldFailOAuth = shouldFailOAuth
        let repository = StubAuthRepository(latest: nil)
        repository.shouldFailSignIn = shouldFailSignIn
        
        return .init(oauth2ServiceProvider: provider, authRepository: repository)
    }
}


extension AuthUsecaseImpleTests {
    
    // signin - oauth 이후 인가까지 완료
    func testUsecase_signIn() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let auth = try? await usecase.signIn(GoogleOAuth2ServiceProvider())
        
        // then
        XCTAssertNotNil(auth)
    }
    
    // signin - no provider
    func testUsecase_whenSignInWithNotSupportProvider_fail() async {
        // given
        struct NotSupportProvider: OAuth2ServiceProvider { var identifier: String = "some" }
        let usecase = self.makeUsecase()
        
        // when
        var failed: (any Error)?
        do {
            let _ = try await usecase.signIn(NotSupportProvider())
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    // signin - oauth 단계에서 실패
    func testUsecase_whenSignIn_andFailAtOauth() async {
        // given
        let usecase = self.makeUsecase(shouldFailOAuth: true)
        
        // when
        var failed: (any Error)?
        do {
            let _ = try await usecase.signIn(GoogleOAuth2ServiceProvider())
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    // signin - 요청하지않은 url 처리 요청시 무시
    func testUsecase_whenSignInNotRequested_notHandleOpenURL() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let handled = usecase.handleAuthenticationResultOrNot(open: URL(string: "https://dummy.com")!)
        
        // then
        XCTAssertEqual(handled, false)
    }
    
    // signin - oauth 이후 인가 실패
    func testUsecase_signInFail_atAuthorize() async {
        // given
        let usecase = self.makeUsecase(shouldFailSignIn: true)
        
        // when
        var failed: (any Error)?
        do {
            let _ = try await usecase.signIn(GoogleOAuth2ServiceProvider())
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
}


private class FakeOAuthUsecaseProvider: OAuth2ServiceUsecaseProvider, @unchecked Sendable {
    
    var shouldFailOAuth: Bool = false
    
    func usecase(
        for provider: any OAuth2ServiceProvider
    ) -> (any OAuth2ServiceUsecase)? {
        
        switch provider {
        case is GoogleOAuth2ServiceProvider:
            return StubGoogleOAuth2Usecase(shouldFailOAuth: shouldFailOAuth)
            
        default: return nil
        }
    }
    
    var supportOAuth2Service: [OAuth2ServiceProvider] {
        [
            GoogleOAuth2ServiceProvider()
        ]
    }
}

private class StubGoogleOAuth2Usecase: OAuth2ServiceUsecase, @unchecked Sendable {
    
    var provider: OAuth2ServiceProvider { GoogleOAuth2ServiceProvider() }
    let shouldFailOAuth: Bool
    
    init(shouldFailOAuth: Bool) {
        self.shouldFailOAuth = shouldFailOAuth
    }
    
    func requestAuthentication() async throws -> any OAuth2Credential {
        guard self.shouldFailOAuth == false
        else {
            throw RuntimeError("failed")
        }
        return GoogleOAuth2Credential(idToken: "some", accessToken: "token")
    }
    
    func handle(open url: URL) -> Bool {
        return true
    }
}
