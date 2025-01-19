//
//  GoogleAPIAuthenticatorTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 1/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Alamofire
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository

struct GoogleAPIAuthenticatorTests {
    
    private let spyRemote: StubRemoteAPI
    private let spyCredentialStore = SpyCredentailStore()
    private let spyListener = SpyAutenticatorTokenRefreshListener()
    
    init() {
        self.spyRemote = .init(responses: Self.response)
    }
    
    private func makeAuthenticator() -> GoogleAPIAuthenticator {
        let authenticator = GoogleAPIAuthenticator(
            googleClientId: "client_id", credentialStore: self.spyCredentialStore
        )
        authenticator.remoteAPI = self.spyRemote
        authenticator.listener = self.spyListener
        return authenticator
    }
}

extension GoogleAPIAuthenticatorTests {
    
    struct EndpointAndNeedToken {
        let endpoint: any Endpoint
        let isNeed: Bool
    }
    
    @Test("endpoint에 따라 adapt 적용 여부 판단", arguments: [
        EndpointAndNeedToken(endpoint: HolidayAPIEndpoints.supportCountry, isNeed: false),
        EndpointAndNeedToken(endpoint: TodoAPIEndpoints.cancelDone, isNeed: false),
        EndpointAndNeedToken(endpoint: FeedbackEndpoints.post, isNeed: false),
        EndpointAndNeedToken(endpoint: GoogleAuthEndpoint.token, isNeed: false),
        EndpointAndNeedToken(endpoint: GoogleCalendarEndpoint.calednarList, isNeed: true),
    ])
    func authenticator_applyTokenIfNeed(_ endpointPerNeed: EndpointAndNeedToken) {
        // given
        let authenticator = self.makeAuthenticator()
        
        // when
        let isNeed = authenticator.shouldAdapt(endpointPerNeed.endpoint)
        
        // then
        #expect(isNeed == endpointPerNeed.isNeed)
    }
    
    @Test func authenticator_refreshToken_success() async throws {
        // given
        let authenticator = self.makeAuthenticator()
        
        // when
        let credential = APICredential(accessToken: "access")
            |> \.refreshToken .~ "refresh_success"
        
        let result = await withCheckedContinuation { continuation in
            authenticator.refresh(credential, for: Session()) { res in
                continuation.resume(returning: res)
            }
        }
        
        // then
        #expect(self.spyRemote.didRequestedPath == "https://oauth2.googleapis.com/token")
        let refreshPayload = self.spyRemote.didRequestedParams ?? [:]
        #expect(refreshPayload["client_id"] as? String == "client_id")
        #expect(refreshPayload["refresh_token"] as? String == "refresh_success")
        #expect(refreshPayload["grant_type"] as? String == "refresh_token")
        
        guard let newCredentail = try? result.get()
        else {
            Issue.record("토큰갱신 실패")
            return
        }
        
        #expect(newCredentail.accessToken == "new_token")
        #expect(newCredentail.refreshToken == "refresh_success")
        
        #expect(self.spyCredentialStore.didUpdateCredentail != nil)
        #expect(self.spyListener.didTokenRefreshed == true)
    }
    
    @Test func authenticator_refreshToken_fail() async throws {
        // given
        let authenticator = self.makeAuthenticator()
        
        // when
        let credential = APICredential(accessToken: "access")
            |> \.refreshToken .~ "refresh_fail"
        
        let result = await withCheckedContinuation { continuation in
            authenticator.refresh(credential, for: Session()) { res in
                continuation.resume(returning: res)
            }
        }
        
        // then
        #expect(self.spyRemote.didRequestedPath == "https://oauth2.googleapis.com/token")
        let refreshPayload = self.spyRemote.didRequestedParams ?? [:]
        #expect(refreshPayload["client_id"] as? String == "client_id")
        #expect(refreshPayload["refresh_token"] as? String == "refresh_fail")
        #expect(refreshPayload["grant_type"] as? String == "refresh_token")
        
        guard case .failure = result
        else {
            Issue.record("토큰갱신이 실패하지 않음")
            return
        }
        #expect(self.spyCredentialStore.didRemoveCredentail == true)
        #expect(self.spyListener.didTokenRefreshFailed == true)
    }
}

private final class SpyCredentailStore: APICredentialStore {
    
    var didUpdateCredentail: APICredential?
    func updateCredential(_ credential: APICredential) {
        self.didUpdateCredentail = credential
    }
    
    var didRemoveCredentail: Bool?
    func removeCredential() {
        self.didRemoveCredentail = true
    }
}

extension GoogleAPIAuthenticatorTests {
    
    private static var response: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                method: .post,
                endpoint: GoogleAuthEndpoint.token,
                parameterCompare: { _, params in
                    return params["refresh_token"] as? String == "refresh_success"
                },
                resultJsonString: .success(
                """
                {
                  "access_token": "new_token",
                  "expires_in": 3920,
                  "scope": "https://www.googleapis.com/auth/drive.metadata.readonly https://www.googleapis.com/auth/calendar.readonly",
                  "token_type": "Bearer"
                }
                """
                )
            ),
            .init(
                method: .post,
                endpoint: GoogleAuthEndpoint.token,
                parameterCompare: { _, params in
                    return params["refresh_token"] as? String == "refresh_fail"
                },
                resultJsonString: .failure(RuntimeError("failed"))
            ),
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.calednarList,
                resultJsonString: .success(
                """
                { }
                """
                )
            )
        ]
    }
}
