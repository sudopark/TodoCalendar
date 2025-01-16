//
//  AuthenticationInterceptorProxyTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 1/17/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Alamofire

@testable import Repository

struct AuthenticationInterceptorProxyTests {
    
    private func makeInterceptor() -> AuthenticationInterceptorProxy<DummyAPIAuthenticator> {
        return .init(authenticator: DummyAPIAuthenticator())
    }
}

extension AuthenticationInterceptorProxyTests {
    
    private var dummyCredential: APICredential {
        return .init(accessToken: "access")
    }
    
    enum Credentials {
        case notNeedCheckAccessTokenExpired
        case needChedckTokenExpiredAndNotExpired
        case needCheckTokenExpired
        
        var credential: APICredential {
            let credential = APICredential(accessToken: "access")
                |> \.refreshToken .~ "refresh"
            switch self {
            case .notNeedCheckAccessTokenExpired:
                return credential
                    |> \.shouldCheckAccessTokenExpirationBeforeRequest .~ false
            case .needChedckTokenExpiredAndNotExpired:
                return credential
                    |> \.shouldCheckAccessTokenExpirationBeforeRequest .~ true
                    |> \.accessTokenExpirationDate .~ Date().addingTimeInterval(100)
            case .needCheckTokenExpired:
                return credential
                    |> \.shouldCheckAccessTokenExpirationBeforeRequest .~ true
                    |> \.accessTokenExpirationDate .~ Date().addingTimeInterval(-100)
            }
        }
    }
    
    @Test("credential 구성값에 따라 refresh 필요 여부 달라짐", arguments: [
        Credentials.notNeedCheckAccessTokenExpired, .needChedckTokenExpiredAndNotExpired, .needCheckTokenExpired
    ])
    func apiCredential_requireRefresh(_ credentialCase: Credentials) {
        // given
        let credential = credentialCase.credential
        
        // when
        let require = credential.requiresRefresh
        
        // then
        switch credentialCase {
        case .notNeedCheckAccessTokenExpired:
            #expect(require == false)
        case .needChedckTokenExpiredAndNotExpired:
            #expect(require == false)
        case .needCheckTokenExpired:
            #expect(require == true)
        }
    }
    
    @Test func interceptor_noCredential_shouldNotAdapt() {
        // given
        let interceptor = self.makeInterceptor()
        interceptor.update(credential: nil)
        
        // when
        let shouldAdapt = interceptor.shouldAdapt(DummyEndpoint())
        
        // then
        #expect(shouldAdapt == false)
    }
    
    @Test func interceptor_hasCredentail_shouldAdapt() {
        // given
        let interceptor = self.makeInterceptor()
        interceptor.update(credential: self.dummyCredential)
        
        // when
        let shouldAdapt = interceptor.shouldAdapt(DummyEndpoint())
        
        // then
        #expect(shouldAdapt == true)
    }
}

private struct DummyEndpoint: Endpoint {
    let subPath: String = "some"
}

private final class DummyAPIAuthenticator: APIAuthenticator {
    
    func apply(_ credential: APICredential, to urlRequest: inout URLRequest) { }
    
    func refresh(_ credential: APICredential, for session: Session, completion: @escaping (Result<APICredential, any Error>) -> Void) {
        
    }
    
    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: APICredential) -> Bool {
        return true
    }
    
    
    typealias Credential = APICredential
    
    var listener: (any AutenticatorTokenRefreshListener)?
    
    func shouldAdapt(_ endpoint: any Endpoint) -> Bool {
        return true
    }
    
    func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: any Error) -> Bool {
        return response.statusCode == 401
    }
}
