//
//  AuthenticationInterceptorProxy.swift
//  RemoteInfra
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Alamofire
import RemoteInfraInterface


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
