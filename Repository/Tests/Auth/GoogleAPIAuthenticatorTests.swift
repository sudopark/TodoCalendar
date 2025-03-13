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
    private let spyCredentialStore: GoogleAPICredentialStoreImple
    private let spyListener = SpyAutenticatorTokenRefreshListener()
    
    init() {
        self.spyRemote = .init(responses: Self.response)
        self.spyCredentialStore = .init(
            serviceIdentifier: "google",
            keyChainStore: FakeKeyChainStore()
        )
    }
    
    private func makeAuthenticator() -> GoogleAPIAuthenticator {
        let authenticator = GoogleAPIAuthenticator(
            googleClientId: "client_id", credentialStore: self.spyCredentialStore
        )
        authenticator.remoteAPI = self.spyRemote
        authenticator.listener = self.spyListener
        let oldCredential = APICredential(accessToken: "old_credential")
        self.spyCredentialStore.saveCredential(oldCredential)
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
        let credentialBeforeRefresh = self.spyCredentialStore.loadCredential()
        
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
        
        let credentialAfterRefresh = self.spyCredentialStore.loadCredential()
        #expect(credentialBeforeRefresh?.accessToken == "old_credential")
        #expect(credentialAfterRefresh?.accessToken == "new_token")
        #expect(self.spyListener.didTokenRefreshed == true)
    }
    
    @Test func authenticator_refreshToken_fail() async throws {
        // given
        let authenticator = self.makeAuthenticator()
        let credentialBeforeRefresh = self.spyCredentialStore.loadCredential()
        
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
        let credentailAfterRefreshFail = self.spyCredentialStore.loadCredential()
        #expect(credentialBeforeRefresh?.accessToken == "old_credential")
        #expect(credentailAfterRefreshFail == nil)
        #expect(self.spyListener.didTokenRefreshFailed == true)
    }
}

private final class FakeKeyChainStore: KeyChainStorage, @unchecked Sendable {
    
    func setupSharedGroup(_ identifier: String) { }
    private var dataMap: [String: Data] = [:]
    
    func load<T>(_ key: String) -> T? where T : Decodable {
        return self.dataMap[key]
            .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    
    func update<T>(_ key: String, _ value: T) where T : Encodable {
        guard let data = try? JSONEncoder().encode(value)
        else { return }
        self.dataMap[key] = data
    }
    
    func remove(_ key: String) {
        self.dataMap[key] = nil
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
