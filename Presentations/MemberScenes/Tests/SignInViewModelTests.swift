//
//  SignInViewModelTests.swift
//  MemberScenesTests
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import MemberScenes

class SignInViewModelTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel(
        shouldFailSignIn: Bool = false
    ) -> SignInViewModelImple {
        let authUsecase = StubAuthUsecase()
        authUsecase.shouldFailSignIn = shouldFailSignIn
        let viewModel = SignInViewModelImple(authUsecase: authUsecase)
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension SignInViewModelTests {
    
    // 지원하는 로그인 방식 제공
    func testViewModel_provideSupportOauthService() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        let providers = viewModel.supportSignInOAuthService
        
        // then
        XCTAssertEqual(providers.count, 1)
        XCTAssertEqual(providers.first is GoogleOAuth2ServiceProvider, true)
    }
    
    // 로그인 - 성공 이후 화면 닫음
    func testViewModel_whenSignInSuccess_closeScene() {
        // given
        let expect = expectation(description: "로그인 성공 이후에는 화면 닫음")
        let viewModel = self.makeViewModel()
        
        self.spyRouter.didCloseCallback = { expect.fulfill() }
        
        // when
        viewModel.signIn(viewModel.supportSignInOAuthService.first!)
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    // 로그인 - 실패시에 에러 알림
    func testViewModel_whenSignInFailed_showError() {
        // given
        let expect = expectation(description: "로그인 - 실패시에 에러 알림")
        let viewModel = self.makeViewModel(shouldFailSignIn: true)
        
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        
        // when
        viewModel.signIn(viewModel.supportSignInOAuthService.first!)
        
        // then
        self.wait(for: [expect], timeout: self.timeoutLong)
    }

    // 로그인 - 시도 이후 성공시에 진행중 업데이트
    func testViewModel_whenSigninAndSuccess_updateIsSigningIn() {
        // given
        let expect = expectation(description: "로그인 - 시도 이후 성공시에 진행중 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isSigningIns = self.waitOutputs(expect, for: viewModel.isSigningIn) {
            viewModel.signIn(viewModel.supportSignInOAuthService.first!)
        }
        
        // then
        XCTAssertEqual(isSigningIns, [false, true, false])
    }
    
    // 로그인 - 시도 이후 실패시에 진행중 업데이트
    func testViewModel_whenSigninAndFailed_updateIsSigningIn() {
        // given
        let expect = expectation(description: "로그인 - 시도 이후 실패시에 진행중 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(shouldFailSignIn: true)
        
        // when
        let isSigningIns = self.waitOutputs(expect, for: viewModel.isSigningIn, timeout: self.timeoutLong) {
            viewModel.signIn(viewModel.supportSignInOAuthService.first!)
        }
        
        // then
        XCTAssertEqual(isSigningIns, [false, true, false])
    }
}

private class SpyRouter: BaseSpyRouter, SignInRouting, @unchecked Sendable {
    
}
