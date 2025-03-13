//
//  Authenticators.swift
//  Repository
//
//  Created by sudo.park on 1/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Alamofire
import Domain
import Extensions


// MARK: - Credential

public struct APICredential: AuthenticationCredential, Sendable {
    
    public let accessToken: String
    public var refreshToken: String?
    public var accessTokenExpirationDate: Date?
    public var refreshTokenExpirationDate: Date?
    public var shouldCheckAccessTokenExpirationBeforeRequest: Bool = false
    
    public init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    public init(auth: Auth) {
        self.init(accessToken: auth.accessToken)
        self.refreshToken = auth.refreshToken
        self.shouldCheckAccessTokenExpirationBeforeRequest = false
    }
    
    public var requiresRefresh: Bool {
        guard self.shouldCheckAccessTokenExpirationBeforeRequest,
              let expireDate = self.accessTokenExpirationDate
        else { return false }
        
        return expireDate <= Date()
    }
}

// MAR: - APICredentialStore

public protocol APICredentialStore {
    func loadCredential() -> APICredential?
    func saveCredential(_ credential: APICredential)
    func updateCredential(_ credential: APICredential)
    func removeCredential()
}


// MARK: - refresh listener

public protocol AutenticatorTokenRefreshListener: AnyObject {
    
    func oauthAutenticator(
        _ authenticator: (any APIAuthenticator)?, didRefresh credential: APICredential
    )
    func oauthAutenticator(
        _ authenticator: (any APIAuthenticator)?, didRefreshFailed error: any Error
    )
}

// MARK: - authenticator & interceptor

public protocol APIAuthenticator: Authenticator {
    
    var listener: AutenticatorTokenRefreshListener? { get set }
    func shouldAdapt(_ endpoint: any Endpoint) -> Bool
}

public protocol APIRequestInterceptor: RequestInterceptor {
    
    associatedtype APIAuthenticatorType: APIAuthenticator
    
    func update(credential: APICredential?)
    func attach(listener: any AutenticatorTokenRefreshListener)
    
    func shouldAdapt(_ endpoint: any Endpoint) -> Bool
}


// MARK: - AuthenticationInterceptorProxy

public final class AuthenticationInterceptorProxy<APIAuthenticatorType: APIAuthenticator>: APIRequestInterceptor where APIAuthenticatorType.Credential == APICredential {
    
    public let authenticator: APIAuthenticatorType
    private let internalInterceptor: AuthenticationInterceptor<APIAuthenticatorType>
    public init(authenticator: APIAuthenticatorType) {
        self.authenticator = authenticator
        self.internalInterceptor = .init(authenticator: authenticator)
    }
    
    public func update(credential: APICredential?) {
        self.internalInterceptor.credential = credential
    }
    
    public func attach(listener: any AutenticatorTokenRefreshListener) {
        self.authenticator.listener = listener
    }
    
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, any Error>) -> Void
    ) {
        
        self.internalInterceptor.adapt(
            urlRequest, for: session, completion: completion
        )
    }
    
    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: any Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        self.internalInterceptor.retry(
            request, for: session, dueTo: error, completion: completion
        )
    }
    
    public func shouldAdapt(_ endpoint: any Endpoint) -> Bool {
        guard self.internalInterceptor.credential != nil
        else {
            return false
        }
        return self.authenticator.shouldAdapt(endpoint)
    }
}
