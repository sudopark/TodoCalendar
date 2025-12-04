//
//  RemoteUserNotificationRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 12/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("RemoteUserNotificationRepositoryImple_Tests")
final class RemoteUserNotificationRepositoryImpleTests {
    
    private let spyEnvStorage = FakeEnvironmentStorage()
    private let stubRemote: StubRemoteAPI
    
    init() {
        self.stubRemote = .init(responses: DummyResponse().response)
    }
    
    private func makeRepository(
        previousTokenAndUserId: (String, String)? = nil
    ) -> RemoteUserNotificationRepositoryImple {
        
        if let (token, userId) = previousTokenAndUserId {
            self.spyEnvStorage.update("fcm_token_\(userId)", token)
        }
        
        return RemoteUserNotificationRepositoryImple(
            remoteAPI: self.stubRemote,
            environmentStorage: self.spyEnvStorage
        )
    }
}


extension RemoteUserNotificationRepositoryImpleTests {
    
    // register
    @Test func repository_register() async throws {
        // given
        let repository = self.makeRepository()
        let info = DeviceInfo() |> \.deviceModel .~ "model"
        
        // when
        try await repository.register(
            "user", fcmToken: "token", deviceInfo: info
        )
        
        // then
        #expect(self.stubRemote.didRequestedPath == "dummy_calendar_api_host/v1/user/notification")
        let params = self.stubRemote.didRequestedParams ?? [:]
        #expect(params["fcm_token"] as? String == "token")
        #expect(params["device_model"] as? String == "model")
        
        let token: String? = self.spyEnvStorage.load("fcm_token_user")
        #expect(token == "token")
    }
    
    // register + fcm token is same with previous + ignore
    @Test func repository_whenRegisterAndPreviousFCMTokenIsEqual_ignore() async throws {
        // given
        let repository = self.makeRepository(
            previousTokenAndUserId: ("prev_token", "user")
        )
        let info = DeviceInfo() |> \.deviceModel .~ "model"
        
        // when
        try await repository.register("user", fcmToken: "prev_token", deviceInfo: info)
        
        // then
        #expect(self.stubRemote.didRequestedPath == nil)
    }
    
    // unregister + remove local fcm token
    @Test func repository_unregister() async throws {
        // given
        let repository = self.makeRepository(
            previousTokenAndUserId: ("prev_token", "user")
        )
        
        // when
        try await repository.unregister("user")
        
        // then
        let token: String? = self.spyEnvStorage.load("fcm_token_user")
        #expect(token == nil)
    }
}


private struct DummyResponse {
    
    
    var response: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .put,
                endpoint: UserAPIEndpoint.notification,
                resultJsonString: .success("{}")
            ),
            .init(
                method: .delete,
                endpoint: UserAPIEndpoint.notification,
                resultJsonString: .success("{}")
            )
        ]
    }
}
