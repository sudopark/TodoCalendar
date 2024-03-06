//
//  OAuthAutenticatorTests.swift
//  Repository
//
//  Created by sudo.park on 3/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Alamofire
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


class OAuthAutenticatorTests: BaseTestCase {
    
    private var remoteEnvironment: RemoteEnvironment!
    private var spyAuthStore: SpyKeyChainStorage!
    private var stubFirebaseService: StubFirebaseAuthService!
    private var spyListener: SpyListener?
    
    override func setUpWithError() throws {
        self.remoteEnvironment = .init(calendarAPIHost: "https://calendar.come")
        self.spyAuthStore = .init()
        self.stubFirebaseService = .init()
        self.spyListener = .init()
    }
    
    override func tearDownWithError() throws {
        self.remoteEnvironment = nil
        self.spyAuthStore = nil
        self.stubFirebaseService = nil
        self.spyListener = nil
    }
    
    private func makeAuthenticator() -> OAuthAutenticator {
        
        let authenticator = OAuthAutenticator(
            authStore: self.spyAuthStore,
            remoteEnvironment: self.remoteEnvironment,
            firebaseAuthService: self.stubFirebaseService
        )
        authenticator.listener = self.spyListener
        return authenticator
    }
    
    private var dummyAuth: Auth {
        return .init(uid: "uid", accessToken: "access", refreshToken: "refresh")
    }
}

extension OAuthAutenticatorTests {
    
    private func makeRequest(_ endpoint: any Endpoint, method: HTTPMethod) -> URLRequest? {
        guard let path = self.remoteEnvironment.path(endpoint),
              let url = URL(string: path)
        else {
            return nil
        }
        return try? URLRequest(url: url, method: method)
    }
    
    // apply token or not
    func testAuthenticator_applyTokenIfNeed() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest(
            _ endpoint: any Endpoint,
            method: HTTPMethod,
            expecthasToken: Bool
        ) {
            // given
            guard var request = self.makeRequest(endpoint, method: method)
            else {
                XCTFail("invalid endpoint")
                return
            }
            
            // when
            let credential = OptionalAuthCredential.need(self.dummyAuth)
            authenticator.apply(credential, to: &request)
            
            // then
            let authHeader = request.headers["Authorization"]
            let token = authHeader?.components(separatedBy: "Bearer ")[safe: 1]
            if expecthasToken {
                XCTAssertEqual(token, "access")
            } else {
                XCTAssertNil(token)
            }
        }
        // when + then
        parameterizeTest(
            HolidayAPIEndpoints.supportCountry, method: .get, expecthasToken: false
        )
        parameterizeTest(
            AccountAPIEndpoints.info, method: .put, expecthasToken: false
        )
        parameterizeTest(
            TodoAPIEndpoints.currentTodo, method: .get, expecthasToken: true
        )
    }
    
    func testAuthenticator_whenCredentialNotNeed_notApplyToken() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest(
            _ endpoint: any Endpoint,
            method: HTTPMethod
        ) {
            // given
            guard var request = self.makeRequest(endpoint, method: method)
            else {
                XCTFail("invalid endpoint")
                return
            }
            
            // when
            let credential = OptionalAuthCredential.notNeed
            authenticator.apply(credential, to: &request)
            
            // then
            let authHeader = request.headers["Authorization"]
            let token = authHeader?.components(separatedBy: "Bearer ")[safe: 1]
            XCTAssertNil(token)
        }
        // when + then
        parameterizeTest(
            HolidayAPIEndpoints.supportCountry, method: .get
        )
        parameterizeTest(
            AccountAPIEndpoints.info, method: .put
        )
        parameterizeTest(
            TodoAPIEndpoints.currentTodo, method: .get
        )
    }
}

extension OAuthAutenticatorTests {
    
    private func makeRequestAndResponse(_ endpoint: any Endpoint, method: HTTPMethod, statusCode: Int) -> (URLRequest, HTTPURLResponse)? {
        guard let path = self.remoteEnvironment.path(endpoint),
              let url = URL(string: path),
              let request = try? URLRequest(url: url, method: method),
              let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: [:])
        else { return nil }
        
        return (request, response)
    }
    
    private func makeResponse(_ statusCode: Int) -> HTTPURLResponse? {
        guard let dummyURL = URL(string: "https://dummy.com") else { return nil }
        return HTTPURLResponse(url: dummyURL, statusCode: statusCode, httpVersion: nil, headerFields: [:])
    }
    
    // check token need to refresh
    func testAuthenticator_checkIsNeedRefresh() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest(
            _ endpoint: any Endpoint, _ method: HTTPMethod,
            _ statusCode: Int, _ error: any Error = RuntimeError("failed"),
            isNeed: Bool
        ) {
            // given
            guard let request = self.makeRequest(endpoint, method: method),
                  let response = self.makeResponse(statusCode)
            else {
                XCTFail("invalid request or response")
                return
            }
            
            // when
            let result = authenticator.didRequest(request, with: response, failDueToAuthenticationError: error)
            
            // then
            XCTAssertEqual(result, isNeed)
        }
        // when + then
        parameterizeTest(
            HolidayAPIEndpoints.supportCountry, .get, 403, isNeed: false
        )
        parameterizeTest(
            HolidayAPIEndpoints.supportCountry, .get, 401, isNeed: false
        )
        parameterizeTest(
            AccountAPIEndpoints.info, .put, 401, isNeed: false
        )
        parameterizeTest(
            AccountAPIEndpoints.info, .put, 403, isNeed: false
        )
        parameterizeTest(
            TodoAPIEndpoints.currentTodo, .get, 403, isNeed: false
        )
        parameterizeTest(
            TodoAPIEndpoints.currentTodo, .get, 401, isNeed: true
        )
    }
    

    // referesh
    func testAuthenticator_refreshToken() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest(_ shouldFail: Bool) {
            // given
            self.stubFirebaseService.shouldFailRefresh = shouldFail
            let expect = expectation(description: "wait-refresh")
            var result: Result<OptionalAuthCredential, any Error>?
            
            // when
            let credential = OptionalAuthCredential.need(self.dummyAuth)
            authenticator.refresh(credential, for: Session()) {
                result = $0
                expect.fulfill()
            }
            self.wait(for: [expect], timeout: self.timeout)
            
            // then
            switch result {
            case .success:
                XCTAssertEqual(shouldFail, false)
                XCTAssertEqual(self.spyListener?.didTokenRefreshed, true)
                XCTAssertEqual(self.spyAuthStore.loadCurrentAuth()?.accessToken, "access-new")
                
            case .failure:
                XCTAssertEqual(shouldFail, true)
                XCTAssertEqual(self.spyListener?.didTokenRefreshFailed, true)
                XCTAssertEqual(self.spyAuthStore.loadCurrentAuth()?.accessToken, nil)
                XCTAssertEqual(self.stubFirebaseService.didSignout, true)
            default:
                XCTFail("refresh failed without response")
            }
        }
        
        // when + then
        parameterizeTest(true)
        parameterizeTest(false)
    }
    
    func testAuthenticator_whenCredentialNotNeed_alwayNotRefreshToken() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest() {
            // given
            let expect = expectation(description: "wait-refresh")
            var result: Result<OptionalAuthCredential, any Error>?
            
            // when
            let credential = OptionalAuthCredential.notNeed
            authenticator.refresh(credential, for: Session()) {
                result = $0
                expect.fulfill()
            }
            self.wait(for: [expect], timeout: self.timeout)
            
            // then
            switch result {
            case .success:
                XCTFail("성공해서는 안됨")
                
            case .failure:
                XCTAssert(true)
                XCTAssertNotEqual(self.spyListener?.didTokenRefreshFailed, true, "해당케이스에서는 리스너 호출안함")
            default:
                XCTFail("refresh failed without response")
            }
        }
        
        // when + then
        parameterizeTest()
        parameterizeTest()
    }
    
    // check token has changed
    func testAuthenticator_checkTokenChanged() {
        // given
        let authenticator = self.makeAuthenticator()
        let newAuth = Auth(uid: "uid", accessToken: "access-new", refreshToken: "refresh-new")
        func parameterizeTest(
            _ stubToken: String?,
            isEqual: Bool
        ) {
            // given
            guard var request = self.makeRequest(TodoAPIEndpoints.currentTodo, method: .get)
            else {
                XCTFail("invalid endpoint")
                return
            }
            request.setValue(stubToken, forHTTPHeaderField: "Authorization")
            
            // when
            let credential = OptionalAuthCredential.need(newAuth)
            let result = authenticator.isRequest(request, authenticatedWith: credential)
            
            // then
            XCTAssertEqual(result, isEqual)
        }
        
        // when + then
        parameterizeTest(nil, isEqual: false)
        parameterizeTest("wrong auth", isEqual: false)
        parameterizeTest("Bearer old", isEqual: false)
        parameterizeTest("Bearer access-new", isEqual: true)
    }
    
    func testAuthenticator_whenCredentialNotNeed_checkTokenChangedAlwaysTrue() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest(
            _ stubToken: String?
        ) {
            // given
            guard var request = self.makeRequest(TodoAPIEndpoints.currentTodo, method: .get)
            else {
                XCTFail("invalid endpoint")
                return
            }
            request.setValue(stubToken, forHTTPHeaderField: "Authorization")
            
            // when
            let credential = OptionalAuthCredential.notNeed
            let result = authenticator.isRequest(request, authenticatedWith: credential)
            
            // then
            XCTAssertEqual(result, true)
        }
        
        // when + then
        parameterizeTest(nil)
        parameterizeTest("wrong auth")
        parameterizeTest("Bearer old")
        parameterizeTest("Bearer access-new")
    }
}

private final class SpyListener: OAuthAutenticatorTokenRefreshListener {
    
    var didTokenRefreshed: Bool?
    func oauthAutenticator(didRefresh auth: Auth) {
        self.didTokenRefreshed = true
    }
    
    var didTokenRefreshFailed: Bool?
    func oauthAutenticator(didRefreshFailed error: any Error) {
        self.didTokenRefreshFailed = true
    }
}
