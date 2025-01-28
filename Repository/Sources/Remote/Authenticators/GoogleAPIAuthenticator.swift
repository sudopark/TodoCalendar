//
//  GoogleAPIAuthenticator.swift
//  Repository
//
//  Created by sudo.park on 1/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
@preconcurrency import Alamofire
import Domain
import Extensions


public final class GoogleAPIAuthenticator: APIAuthenticator, @unchecked Sendable {
    
    public typealias Credential = APICredential
    
    private let googleClientId: String
    private let credentialStore: any APICredentialStore
    
    public weak var remoteAPI: (any RemoteAPI)?
    public weak var listener: (any AutenticatorTokenRefreshListener)?
    
    init(
        googleClientId: String,
        credentialStore: any APICredentialStore
    ) {
        self.googleClientId = googleClientId
        self.credentialStore = credentialStore
    }
}


// MARK: - apply token if need

extension GoogleAPIAuthenticator {
    
    public func shouldAdapt(_ endpoint: any Endpoint) -> Bool {
        
        switch endpoint {
        case let auth as GoogleAuthEndpoint where auth == .token: return false
        case is GoogleCalendarEndpoint: return true
        default: return false
        }
    }
    
    public func apply(_ credential: APICredential, to urlRequest: inout URLRequest) {
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
    }
}


// MARK: - check is need refresh + refresh

private struct GoogleAPIAccessTokenRefreshResult: Decodable, Sendable {
    let accessToken: String
    let expiresIn: TimeInterval
    var scope: String?
    var tokenType: String?
    
    private enum CodingKeys: String, CodingKey {
        case access_token
        case expires_in
        case scope
        case token_type
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .access_token)
        self.expiresIn = try container.decode(TimeInterval.self, forKey: .expires_in)
        self.scope = try? container.decode(String.self, forKey: .scope)
        self.tokenType = try? container.decode(String.self, forKey: .token_type)
    }
}

extension GoogleAPIAuthenticator {
    
    public func didRequest(
        _ urlRequest: URLRequest,
        with response: HTTPURLResponse,
        failDueToAuthenticationError error: any Error
    ) -> Bool {
        // TODO: 만료 응답 확인 필요
        
        return response.statusCode == 401
    }
    
    public func refresh(
        _ credential: APICredential,
        for session: Session,
        completion: @escaping @Sendable (Result<APICredential, any Error>) -> Void
    ) {
        
        logger.log(level: .debug, "google api token refresh start..")
        
        guard let refreshToken = credential.refreshToken
        else {
            logger.log(level: .error, "google api refresh token not exists")
            completion(.failure(RuntimeError("google api refresh token not exists")))
            return
        }
        
        let endpoint = GoogleAuthEndpoint.token
        let payload: [String: Any] = [
            "client_id" : self.googleClientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        Task { [weak self] in
            do {
                guard let result: GoogleAPIAccessTokenRefreshResult = try await self?.remoteAPI?.request(
                    .post, endpoint,
                    parameters: payload
                )
                else {
                    return
                }
                
                logger.log(level: .debug, "google api token refreshed, and is changed: \(credential.accessToken != result.accessToken)")
                let newCredential = APICredential(accessToken: result.accessToken)
                    |> \.refreshToken .~ refreshToken
                    |> \.accessTokenExpirationDate .~ (Date().addingTimeInterval(result.expiresIn))
                self?.credentialStore.updateCredential(newCredential)
                self?.listener?.oauthAutenticator(self, didRefresh: newCredential)
                completion(.success(newCredential))
            } catch {
                logger.log(level: .error, "google api token refresh fail..:\(error)")
                self?.credentialStore.removeCredential()
                self?.listener?.oauthAutenticator(self, didRefreshFailed: error)
                completion(.failure(error))
            }
        }
    }
    
    public func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: APICredential) -> Bool {
        let bearerToken = HTTPHeader.authorization(bearerToken: credential.accessToken).value
        let isSameCredential = urlRequest.headers["Authorization"] == bearerToken
        let path = urlRequest.urlRequest?.url?.absoluteString ?? ""
        if !isSameCredential {
            logger.log(level: .debug, "google api credentail changed, the request will resume path: \(path)")
        } else {
            logger.log(level: .error, "google api current credentail is invalid, will resume request after refresh(if need), path: \(path)")
        }
        return isSameCredential
    }
}
