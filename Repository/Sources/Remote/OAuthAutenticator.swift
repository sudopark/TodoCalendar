//
//  OAuthAutenticator.swift
//  Repository
//
//  Created by sudo.park on 3/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Alamofire


extension Auth: AuthenticationCredential {
    
    public var requiresRefresh: Bool { false }
}


protocol OAuthAutenticatorTokenRefreshListener: AnyObject {
    
    func oauthAutenticator(didRefresh auth: Auth)
    func oauthAutenticator(didRefreshFailed error: any Error)
}

final class OAuthAutenticator: Authenticator {
    
    typealias Credential = Auth
    
    private let remoteEnvironment: RemoteEnvironment
    private let firebaseAuthService: any FirebaseAuthService
    
    weak var listener: OAuthAutenticatorTokenRefreshListener?
    
    init(
        remoteEnvironment: RemoteEnvironment,
        firebaseAuthService: any FirebaseAuthService
    ) {
        self.remoteEnvironment = remoteEnvironment
        self.firebaseAuthService = firebaseAuthService
    }
}


// MARK: - apply token if need

extension OAuthAutenticator {
    
    func apply(_ credential: Credential, to urlRequest: inout URLRequest) {
        guard let path = urlRequest.url?.absoluteString,
              self.isNeedToken(path) else { return }
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
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
    
    func didRequest(
        _ urlRequest: URLRequest,
        with response: HTTPURLResponse,
        failDueToAuthenticationError error: Error
    ) -> Bool {
        
        guard let path = urlRequest.url?.absoluteString,
              self.isNeedToken(path)
        else { return false }
        
        return response.statusCode == 401
    }
    
    func refresh(
        _ credential: Credential,
        for session: Session,
        completion: @escaping (Result<Credential, Error>) -> Void
    ) {
        
        self.firebaseAuthService.refreshToken { result in
            switch result {
            case .success(let refreshResult):
                let auth = Auth(
                    uid: refreshResult.uid,
                    accessToken: refreshResult.idToken,
                    refreshToken: refreshResult.refreshToken
                )
                self.listener?.oauthAutenticator(didRefresh: auth)
                completion(.success(auth))
                
            case .failure(let error):
                self.listener?.oauthAutenticator(didRefreshFailed: error)
                completion(.failure(error))
            }
        }
    }
    
    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool {
        let bearerToken = HTTPHeader.authorization(bearerToken: credential.accessToken).value
        return urlRequest.headers["Authorization"] == bearerToken
    }
}
