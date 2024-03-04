//
//  OAuthAutenticator.swift
//  Repository
//
//  Created by sudo.park on 3/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Alamofire
import Domain
import Extensions


public enum OptionalAuthCredential: AuthenticationCredential {
    case notNeed
    case need(Auth)
    
    public var requiresRefresh: Bool { false }

    var auth: Auth? {
        guard case let .need(auth) = self else { return nil }
        return auth
    }
}

public protocol OAuthAutenticatorTokenRefreshListener: AnyObject {
    
    func oauthAutenticator(didRefresh auth: Auth)
    func oauthAutenticator(didRefreshFailed error: any Error)
}

public final class OAuthAutenticator: Authenticator {
    
    public typealias Credential = OptionalAuthCredential
    
    private let authStore: any AuthStore
    private let remoteEnvironment: RemoteEnvironment
    private let firebaseAuthService: any FirebaseAuthService
    
    public weak var listener: OAuthAutenticatorTokenRefreshListener?
    
    public init(
        authStore: any AuthStore,
        remoteEnvironment: RemoteEnvironment,
        firebaseAuthService: any FirebaseAuthService
    ) {
        self.authStore = authStore
        self.remoteEnvironment = remoteEnvironment
        self.firebaseAuthService = firebaseAuthService
    }
}


// MARK: - apply token if need

extension OAuthAutenticator {
    
    public func apply(_ credential: Credential, to urlRequest: inout URLRequest) {
        guard let auth = credential.auth,
              let path = urlRequest.url?.absoluteString,
              self.isNeedToken(path) else { return }
        urlRequest.headers.add(.authorization(bearerToken: auth.accessToken))
    }
    
    private func isNeedToken(_ urlPath: String) -> Bool {
        let accountPath = self.remoteEnvironment.path(AccountAPIEndpoints.account)
        if accountPath.map ({ urlPath.starts(with: $0) }) == true {
            return false
        } else if urlPath.starts(with: self.remoteEnvironment.calendarAPIHost) {
            return true
        } else {
            return false
        }
    }
}

// MARK: - check is need refresh + refresh

extension OAuthAutenticator {
    
    public func didRequest(
        _ urlRequest: URLRequest,
        with response: HTTPURLResponse,
        failDueToAuthenticationError error: Error
    ) -> Bool {
        
        guard let path = urlRequest.url?.absoluteString,
              self.isNeedToken(path)
        else { return false }
        
        return response.statusCode == 401
    }
    
    public func refresh(
        _ credential: Credential,
        for session: Session,
        completion: @escaping (Result<Credential, Error>) -> Void
    ) {
        
        guard case .need = credential
        else {
            completion(.failure(RuntimeError("auth not exists")))
            return
        }
        
        self.firebaseAuthService.refreshToken { result in
            switch result {
            case .success(let refreshResult):
                let auth = Auth(
                    uid: refreshResult.uid,
                    accessToken: refreshResult.idToken,
                    refreshToken: refreshResult.refreshToken
                )
                self.authStore.updateAuth(auth)
                self.listener?.oauthAutenticator(didRefresh: auth)
                completion(.success(.need(auth)))
                
            case .failure(let error):
                self.listener?.oauthAutenticator(didRefreshFailed: error)
                completion(.failure(error))
            }
        }
    }
    
    public func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool {
        switch credential {
        case .notNeed:
            return true
            
        case .need(let auth):
            let bearerToken = HTTPHeader.authorization(bearerToken: auth.accessToken).value
            return urlRequest.headers["Authorization"] == bearerToken
        }
    }
}
