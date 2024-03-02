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
    private var stubFirebaseService: StubFirebaseAuthService!
    private var spyKeychainStore: SpyKeyChainStorage!
    
    override func setUpWithError() throws {
        self.remoteEnvironment = .init(calendarAPIHost: "https://calendar.come")
        self.stubFirebaseService = .init()
        self.spyKeychainStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.remoteEnvironment = nil
        self.stubFirebaseService = nil
        self.spyKeychainStore = nil
    }
    
    private func makeAuthenticator() -> OAuthAutenticator {
        
        return .init(
            remoteEnvironment: self.remoteEnvironment,
            firebaseAuthService: self.stubFirebaseService,
            keyChainStore: self.spyKeychainStore
        )
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
            authenticator.apply(self.dummyAuth, to: &request)
            
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
            AccountAPIEndpoints.account, method: .put, expecthasToken: false
        )
        parameterizeTest(
            TodoAPIEndpoints.currentTodo, method: .get, expecthasToken: true
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
            AccountAPIEndpoints.account, .put, 401, isNeed: false
        )
        parameterizeTest(
            AccountAPIEndpoints.account, .put, 403, isNeed: false
        )
        parameterizeTest(
            TodoAPIEndpoints.currentTodo, .get, 403, isNeed: false
        )
        parameterizeTest(
            TodoAPIEndpoints.currentTodo, .get, 401, isNeed: true
        )
    }
    

    // referesh and save auth
    func testAuthenticator_whenRefreshToken_saveAuth() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest(_ shouldFail: Bool) {
            // given
            self.spyKeychainStore.remove("current_auth")
            self.stubFirebaseService.shouldFailRefresh = shouldFail
            let expect = expectation(description: "wait-refresh")
            var result: Result<Auth, any Error>?
            
            // when
            authenticator.refresh(self.dummyAuth, for: Session()) {
                result = $0
                expect.fulfill()
            }
            self.wait(for: [expect], timeout: self.timeout)
            
            // then
            switch result {
            case .success:
                XCTAssertEqual(shouldFail, false)
                let newAuth: AuthMapper? = self.spyKeychainStore.load("current_auth")
                XCTAssertNotNil(newAuth?.auth)
                
            case .failure:
                XCTAssertEqual(shouldFail, true)
            default:
                XCTFail("refresh failed without response")
            }
        }
        
        // when + then
        parameterizeTest(true)
        parameterizeTest(false)
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
            let result = authenticator.isRequest(request, authenticatedWith: newAuth)
            
            // then
            XCTAssertEqual(result, isEqual)
        }
        
        // when + then
        parameterizeTest(nil, isEqual: false)
        parameterizeTest("wrong auth", isEqual: false)
        parameterizeTest("Bearer old", isEqual: false)
        parameterizeTest("Bearer access-new", isEqual: true)
    }
}
