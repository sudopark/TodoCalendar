//
//  AccountUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class AccountUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
    }
    
    private var dummyAuth: Auth {
        return .init(uid: "dummy", accessToken: "token", refreshToken: "refresh")
    }
    
    private func makeUsecase(
        latestAccount: Account? = nil,
        shouldFailOAuth: Bool = false,
        shouldFailSignIn: Bool = false
    ) -> AccountUsecaseImple {
        
        let provider = FakeOAuthUsecaseProvider()
        provider.shouldFailOAuth = shouldFailOAuth
        let repository = StubAuthRepository(latest: latestAccount)
        repository.shouldFailSignIn = shouldFailSignIn
        
        return .init(
            oauth2ServiceProvider: provider,
            authRepository: repository,
            sharedStore: SharedDataStore()
        )
    }
}

extension AccountUsecaseImpleTests {
    
    // 마지막 로그인 정보 준비
    func testUsecase_prepareLatestSignInInfo() async {
        // given
        func parameterizeTest(expectHasAccount: Bool) async {
            // given
            let usecase = self.makeUsecase(
                latestAccount: expectHasAccount
                ? .init(auth: .init(uid: "id", accessToken: "token"), info: .init("id"))
                : nil
            )
            
            // when
            let account = try? await usecase.prepareLastSignInAccount()
            
            // then
            XCTAssertEqual(account != nil, expectHasAccount)
        }
        
        // when + then
        await parameterizeTest(expectHasAccount: true)
        await parameterizeTest(expectHasAccount: false)
    }
    
    // 마지막 로그인 정보 준비 이후에 현재 계정정보 세팅
    func testUsecase_whenAfterPrepareLatestSignInInfo_updateCurrentAccount() {
        // given
        let expect = expectation(description: "마지막 로그인 정보 준비 이후에 현재 계정정보 세팅")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(
            latestAccount: .init(auth: .init(uid: "id", accessToken: "token"), info: .init("id"))
        )
        
        // when
        let accountInfos = self.waitOutputs(expect, for: usecase.currentAccountInfo) {
            Task {
                try await usecase.prepareLastSignInAccount()
            }
        }
        
        // then
        let hasAccount = accountInfos.map { $0 != nil }
        XCTAssertEqual(hasAccount, [false, true])
    }
}

extension AccountUsecaseImpleTests {
    
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
    
    func testUsecase_whenAfterSignIn_updateCurrentAccountInfo() {
        // given
        let expect = expectation(description: "로그인 이후에 현재 계정정보 업데이트")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let infos = self.waitOutputs(expect, for: usecase.currentAccountInfo) {
            Task {
                try await usecase.signIn(GoogleOAuth2ServiceProvider())
            }
        }
        
        // then
        let hasAccount = infos.map { $0 != nil }
        XCTAssertEqual(hasAccount, [false, true])
    }
    
    func testUsecase_whenAfterSignIn_notify() {
        // given
        let expect = expectation(description: "로그인 이후에 로그인 되었음을 알림")
        let usecase = self.makeUsecase()
        
        // when
        let event = self.waitFirstOutput(expect, for: usecase.accountStatusChanged) {
            Task {
                try await usecase.signIn(GoogleOAuth2ServiceProvider())
            }
        }
        
        // then
        if case .signedIn = event {
            XCTAssert(true)
        } else {
           XCTFail("로그인 이벤트 안나옴")
        }
    }
    
    func testUescase_signOut() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        try await usecase.signOut()
        
        // then
        XCTAssert(true)
    }
    
    func testUsecase_whenAfterSignout_clearSharedAccountInfo() {
        // given
        let expect = expectation(description: "로그아웃 이후 공유중인 계정정보 초기화")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecase()
        
        // when
        let infos = self.waitOutputs(expect, for: usecase.currentAccountInfo) {
            Task {
                _ = try await usecase.signIn(GoogleOAuth2ServiceProvider())
                try await usecase.signOut()
            }
        }
        
        // then
        let accountInfoIsNils = infos.map { $0 == nil }
        XCTAssertEqual(accountInfoIsNils, [true, false, true])
    }
    
    func testUsecase_whenAfterSignout_notify() {
        // given
        let expect = expectation(description: "로그아웃 이후 이벤트 전파")
        let usecase = self.makeUsecase()
        
        // when
        let event = self.waitFirstOutput(expect, for: usecase.accountStatusChanged) {
            Task {
                try await usecase.signOut()
            }
        }
        
        // then
        if case .signOut = event {
            XCTAssert(true)
        } else {
            XCTFail("기대한 이벤트가 아님")
        }
    }
    
    func testUescase_deleteAccount() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        try await usecase.deleteAccount()
        
        // then
        XCTAssert(true)
    }
    
    func testUsecase_whenAfterDeleteAccount_clearSharedAccountInfo() {
        // given
        let expect = expectation(description: "회원탈퇴 이후 공유중인 계정정보 초기화")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecase()
        
        // when
        let infos = self.waitOutputs(expect, for: usecase.currentAccountInfo) {
            Task {
                _ = try await usecase.signIn(GoogleOAuth2ServiceProvider())
                try await usecase.deleteAccount()
            }
        }
        
        // then
        let accountInfoIsNils = infos.map { $0 == nil }
        XCTAssertEqual(accountInfoIsNils, [true, false, true])
    }
    
    func testUsecase_whenAfterDeleteAccount_notify() {
        // given
        let expect = expectation(description: "회원탈퇴 이후 이벤트 전파")
        let usecase = self.makeUsecase()
        
        // when
        let event = self.waitFirstOutput(expect, for: usecase.accountStatusChanged) {
            Task {
                try await usecase.deleteAccount()
            }
        }
        
        // then
        if case .signOut = event {
            XCTAssert(true)
        } else {
            XCTFail("기대한 이벤트가 아님")
        }
    }
    
    func testUsecase_appleSignIn() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let provider = AppleOAuth2ServiceProvider()
        provider.appleSignInResult = .success(.init(appleIDToken: "token", nonce: "nonce"))
        let account = try await usecase.signIn(provider)
        
        // then
        XCTAssertEqual(account.auth.uid, "id")
    }
    
    func testUsecase_appleSignIn_failed() async {
        // given
        func parameterizeTest(hasPrehandleErrorResult: Bool) async {
            // given
            let usecase = self.makeUsecase()
            
            // when
            let provider = AppleOAuth2ServiceProvider()
            if hasPrehandleErrorResult {
                provider.appleSignInResult = .failure(RuntimeError("failed"))
            }
            
            // then
            do {
                let _ = try await usecase.signIn(provider)
                XCTFail("로그인에 실패해야함")
            } catch {
                XCTAssert(true)
            }
        }
        // when + then
        await parameterizeTest(hasPrehandleErrorResult: true)
        await parameterizeTest(hasPrehandleErrorResult: false)
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
            
        case let apple as AppleOAuth2ServiceProvider:
            return AppleOAuth2ServiceUsecaseImple(preHandleResult: apple.appleSignInResult)
            
        default: return nil
        }
    }
    
    var supportOAuth2Service: [OAuth2ServiceProvider] {
        [
            GoogleOAuth2ServiceProvider(),
            AppleOAuth2ServiceProvider()
        ]
    }
}

private class StubGoogleOAuth2Usecase: OAuth2ServiceUsecase, @unchecked Sendable {
    
    typealias CredentialType = GoogleOAuth2Credential
    
    var provider: OAuth2ServiceProvider { GoogleOAuth2ServiceProvider() }
    let shouldFailOAuth: Bool
    
    init(shouldFailOAuth: Bool) {
        self.shouldFailOAuth = shouldFailOAuth
    }
    
    func requestAuthentication() async throws -> GoogleOAuth2Credential {
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
