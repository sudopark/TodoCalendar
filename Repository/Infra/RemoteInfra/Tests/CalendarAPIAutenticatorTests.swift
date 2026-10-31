//
//  CalendarAPIAutenticatorTests.swift
//  RemoteInfraTests
//
//  Created by sudo.park on 3/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Alamofire
import Prelude
import Optics
import Extensions
import UnitTestHelpKit
import RemoteInfraInterface
import RemoteInfraTesting

@testable import RemoteInfra
import AccountDomainInterface


class CalendarAPIAutenticatorTests: BaseTestCase {
    
    private var remoteEnvironment: RemoteEnvironment!
    private var spyAuthStore: SpyKeyChainStorage!
    private var stubFirebaseService: StubFirebaseAuthService!
    private var spyListener: SpyAutenticatorTokenRefreshListener?
    
    override func setUpWithError() throws {
        self.remoteEnvironment = .init(calendarAPIHost: "https://calendar.come", csAPI: "cs_api", deviceId: "device_id", acceptLanguage: { "en" })
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
    
    private func makeAuthenticator(refreshFailError: (any Error)? = nil) -> CalendarAPIAutenticator {

        self.stubFirebaseService.refreshFailError = refreshFailError
        let authenticator = CalendarAPIAutenticator(
            credentialStore: self.spyAuthStore,
            firebaseAuthService: self.stubFirebaseService
        )
        authenticator.listener = self.spyListener
        return authenticator
    }
    
    private var dummyAuth: Auth {
        return .init(uid: "uid", accessToken: "access", refreshToken: "refresh")
    }
}

extension CalendarAPIAutenticatorTests {
    
    private func makeRequest(_ endpoint: any Endpoint, method: HTTPMethod) -> URLRequest? {
        guard let url = URL(string: self.remoteEnvironment.path(endpoint))
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
            
            // when
            let isNeed = authenticator.shouldAdapt(endpoint)
            
            
            // then
            XCTAssertEqual(isNeed, expecthasToken)
        }
        // when + then
        parameterizeTest(
            DummyEndpoint.external, method: .get, expecthasToken: false
        )
        parameterizeTest(
            DummyEndpoint.calendarAPIWithoutAuthorization, method: .put, expecthasToken: false
        )
        parameterizeTest(
            DummyEndpoint.google, method: .get, expecthasToken: false
        )
        parameterizeTest(
            DummyEndpoint.calendarAPI, method: .get, expecthasToken: true
        )
    }
}

extension CalendarAPIAutenticatorTests {
    
    private func makeRequestAndResponse(_ endpoint: any Endpoint, method: HTTPMethod, statusCode: Int) -> (URLRequest, HTTPURLResponse)? {
        guard let url = URL(string: self.remoteEnvironment.path(endpoint)),
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
            DummyEndpoint.external, .get, 403, isNeed: false
        )
        parameterizeTest(
            DummyEndpoint.calendarAPIWithoutAuthorization, .put, 403, isNeed: false
        )
        parameterizeTest(
            DummyEndpoint.calendarAPI, .get, 403, isNeed: false
        )
        parameterizeTest(
            DummyEndpoint.calendarAPI, .get, 401, isNeed: true
        )
    }
    

    // referesh
    func testAuthenticator_refreshToken() {
        // given
        let authenticator = self.makeAuthenticator()
        func parameterizeTest(_ shouldFail: Bool) {
            // given
            self.spyAuthStore.saveAuth(self.dummyAuth)
            self.stubFirebaseService.refreshFailError = shouldFail ? RuntimeError("failed") : nil
            let expect = expectation(description: "wait-refresh")
            var result: Result<APICredential, any Error>?
            
            // when
            let credential = APICredential(auth: self.dummyAuth)
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

    func testAuthenticator_whenRefreshFailWithoutServerResponse_keepCredentialAndNotSignOut() {
        // given
        let refreshFailError = NSError(
            domain: "FIRAuthErrorDomain",
            code: 17020,
            userInfo: [NSUnderlyingErrorKey: URLError(.timedOut)]
        )
        let authenticator = self.makeAuthenticator(refreshFailError: refreshFailError)
        self.spyAuthStore.saveAuth(self.dummyAuth)
        let expect = expectation(description: "wait-refresh")
        var result: Result<APICredential, any Error>?

        // when
        let credential = APICredential(auth: self.dummyAuth)
        authenticator.refresh(credential, for: Session()) {
            result = $0
            expect.fulfill()
        }
        self.wait(for: [expect], timeout: self.timeout)

        // then
        guard case .failure = result
        else {
            XCTFail("refresh should fail")
            return
        }
        XCTAssertEqual(self.spyAuthStore.loadCurrentAuth()?.accessToken, "access")
        XCTAssertEqual(self.spyListener?.didTokenRefreshFailed, nil)
        XCTAssertEqual(self.stubFirebaseService.didSignout, nil)
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
            guard var request = self.makeRequest(DummyEndpoint.calendarAPI, method: .get)
            else {
                XCTFail("invalid endpoint")
                return
            }
            request.setValue(stubToken, forHTTPHeaderField: "Authorization")
            
            // when
            let credential = APICredential(auth: newAuth)
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
}

final class SpyAutenticatorTokenRefreshListener: AutenticatorTokenRefreshListener {
    
    var didTokenRefreshed: Bool?
    func oauthAutenticator(
        _ authenticator: (any APIAuthenticator)?,
        didRefresh credential: APICredential
    ) {
        self.didTokenRefreshed = true
    }
    
    var didTokenRefreshFailed: Bool?
    func oauthAutenticator(
        _ authenticator: (any APIAuthenticator)?,
        didRefreshFailed error: any Error
    ) {
        self.didTokenRefreshFailed = true
    }
}
