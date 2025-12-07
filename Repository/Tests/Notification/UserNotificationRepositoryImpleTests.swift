//
//  UserNotificationRepositoryImpleTests.swift
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
import SQLiteService
import UnitTestHelpKit

@testable import Repository


@Suite("UserNotificationRepositoryImpleTests")
final class UserNotificationRepositoryImpleTests: LocalTestable {
    
    var sqliteService: SQLiteService = .init()
    private let stubRemote: StubRemoteAPI
    
    init() {
        self.stubRemote = .init(responses: DummyResponse().response)
    }
    
    private func makeRepository(
        previousToken: String? = nil
    ) throws -> UserNotificationRepositoryImple {
        
        if let previousToken {
            _ = sqliteService.run { db in
                try db.insertOne(
                    KeyValueTable.self,
                    entity: KeyValueTable.Entity(.fcmToken, value: previousToken),
                    shouldReplace: true
                )
            }
        }
        
        return UserNotificationRepositoryImple(
            remoteAPI: self.stubRemote,
            sqliteService: sqliteService
        )
    }
    
    private func fetchFcmToken() -> String? {
        let result = self.sqliteService.run { db in
            let qry = KeyValueTable.selectAll { $0.key == KeyValueTableKeys.fcmToken.rawValue }
            return try db.loadOne(KeyValueTable.self, query: qry)
        }
        return try? result.get()?.value
    }
}


extension UserNotificationRepositoryImpleTests {
    
    // register
    @Test func repository_register() async throws {
        try await self.runTestWithOpenClose("user_noti_1") {
            // given
            let repository = try self.makeRepository()
            let info = DeviceInfo() |> \.deviceModel .~ "model"
            
            // when
            try await repository.register(
                fcmToken: "token", deviceInfo: info
            )
            
            // then
            #expect(self.stubRemote.didRequestedPath == "dummy_calendar_api_host/v1/user/notification")
            let params = self.stubRemote.didRequestedParams ?? [:]
            #expect(params["fcm_token"] as? String == "token")
            #expect(params["device_model"] as? String == "model")
            
            let token = self.fetchFcmToken()
            #expect(token == "token")
        }
    }
    
    // register + fcm token is same with previous + ignore
    @Test func repository_whenRegisterAndPreviousFCMTokenIsEqual_ignore() async throws {
        try await self.runTestWithOpenClose("user_noti_2") {
            // given
            let repository = try self.makeRepository(previousToken: "prev_token")
            let info = DeviceInfo() |> \.deviceModel .~ "model"
            
            // when
            try await repository.register(fcmToken: "prev_token", deviceInfo: info)
            
            // then
            #expect(self.stubRemote.didRequestedPath == nil)
        }
    }
    
    // unregister + remove local fcm token
    @Test func repository_unregister() async throws {
        try await self.runTestWithOpenClose("user_noti_3") {
            // given
            let repository = try self.makeRepository(previousToken: "prev_token")
            
            // when
            try await repository.unregister()
            
            // then
            let token = self.fetchFcmToken()
            #expect(token == nil)
        }
    }
}


private struct DummyResponse {
    
    
    var response: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .put,
                endpoint: UserAPIEndpoints.notification,
                resultJsonString: .success("{}")
            ),
            .init(
                method: .delete,
                endpoint: UserAPIEndpoints.notification,
                resultJsonString: .success("{}")
            )
        ]
    }
}
