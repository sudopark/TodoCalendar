//
//  OAuthAutenticator.swift
//  Repository
//
//  Created by sudo.park on 3/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Alamofire
import Domain
import Extensions

public final class CalendarAPIAutenticator: APIAuthenticator {
    
    public typealias Credential = APICredential
    
    private let credentialStore: any APICredentialStore
    private let firebaseAuthService: any FirebaseAuthService
    
    public weak var listener: (any AutenticatorTokenRefreshListener)?
    
    public init(
        credentialStore: any APICredentialStore,
        firebaseAuthService: any FirebaseAuthService
    ) {
        self.credentialStore = credentialStore
        self.firebaseAuthService = firebaseAuthService
    }
}


// MARK: - apply token if need

extension CalendarAPIAutenticator {
    
    public func shouldAdapt(_ endpoint: any Endpoint) -> Bool {
        switch endpoint {
        case let account as AccountAPIEndpoints where account == .info:
            return false
        case is TodoAPIEndpoints: return true
        case is ScheduleEventEndpoints: return true
        case is ForemostEventEndpoints: return true
        case is EventTagEndpoints: return true
        case is EventDetailEndpoints: return true
        case is AppSettingEndpoints: return true
        case is MigrationEndpoints: return true
        default: return false
        }
    }
    
    public func apply(_ credential: Credential, to urlRequest: inout URLRequest) {
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
    }
}

// MARK: - check is need refresh + refresh

extension CalendarAPIAutenticator {
    
    public func didRequest(
        _ urlRequest: URLRequest,
        with response: HTTPURLResponse,
        failDueToAuthenticationError error: Error
    ) -> Bool {
        
        return response.statusCode == 401
    }
    
    public func refresh(
        _ credential: Credential,
        for session: Session,
        completion: @escaping (Result<Credential, Error>) -> Void
    ) {
        
        let refreshStartTime = Date()
        logger.log(level: .debug, "token refresh start..")
        self.firebaseAuthService.refreshToken {  [weak self] result in
            switch result {
            case .success(let refreshResult):
                let interval = Date().timeIntervalSince(refreshStartTime)
                logger.log(level: .debug, "token refreshed!, interval: \(interval*1000)ms and is chanegd: \(credential.accessToken != refreshResult.idToken)")

                let credential = APICredential(accessToken: refreshResult.idToken)
                    |> \.refreshToken .~ refreshResult.refreshToken
                self?.credentialStore.updateCredential(credential)
                self?.listener?.oauthAutenticator(self, didRefresh: credential)
                completion(.success(credential))
                
            case .failure(let error):
                logger.log(level: .error, "token refresh failed..\(error)")
                try? self?.firebaseAuthService.signOut()
                self?.credentialStore.removeCredential()
                self?.listener?.oauthAutenticator(self, didRefreshFailed: error)
                completion(.failure(error))
            }
        }
    }
    
    public func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool {
        let bearerToken = HTTPHeader.authorization(bearerToken: credential.accessToken).value
        let isSameCredential = urlRequest.headers["Authorization"] == bearerToken
        if !isSameCredential {
            logger.log(level: .debug, "credential changed, the request will resume, path: \(urlRequest.urlRequest?.url?.absoluteString ?? "")")
        } else {
            logger.log(level: .error, "current credential is invalid, will resume request after refresh(if need), path: \(urlRequest.urlRequest?.url?.absoluteString ?? "")")
        }
        return isSameCredential
    }
}
