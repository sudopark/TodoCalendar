//
//  UserNotificationRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import SQLiteService

// MARK: - UserNotificationRepository

public final class UserNotificationRepositoryImple: UserNotificationRepository {
    
    private let remoteAPI: any RemoteAPI
    private let sqliteService: SQLiteService
    
    public init(
        remoteAPI: any RemoteAPI,
        sqliteService: SQLiteService
    ) {
        self.remoteAPI = remoteAPI
        self.sqliteService = sqliteService
    }
}


extension UserNotificationRepositoryImple {
    
    struct NotificationRegisterResult: Decodable { }
    
    public func register(
        fcmToken: String, deviceInfo: DeviceInfo
    ) async throws {
        
        let previousToken = try? await self.fetchSavedFcmToken()
        
        guard previousToken != fcmToken else { return }
        
        let endpoint = UserAPIEndpoints.notification
        var payload: [String: Any] = [
            "fcm_token": fcmToken
        ]
        payload["device_model"] = deviceInfo.deviceModel
        
        let _: NotificationRegisterResult = try await self.remoteAPI.request(
            .put, endpoint, parameters: payload
        )
        
        try? await self.updateToken(fcmToken)
    }
    
    public func unregister() async throws {
        
        typealias UnregisterResult = NotificationRegisterResult
        
        let endpoint = UserAPIEndpoints.notification
        
        let _: UnregisterResult = try await self.remoteAPI.request(
            .delete, endpoint
        )
        try? await self.removeFcmToken()
    }
}

extension UserNotificationRepositoryImple {
    
    private typealias KV = KeyValueTable
    
    private func fetchSavedFcmToken() async throws -> String? {
        let key = KeyValueTableKeys.fcmToken.rawValue
        return try await self.sqliteService.async.run { db in
            let query = KV.selectAll { $0.key == key }
            return try db.loadOne(KV.self, query: query)?.value
        }
    }
    
    private func updateToken(_ token: String) async throws {
        try await self.sqliteService.async.run { db in
            let entity = KV.Entity(.fcmToken, value: token)
            try db.insertOne(KV.self, entity: entity, shouldReplace: true)
        }
    }
    
    private func removeFcmToken() async throws {
        let key = KeyValueTableKeys.fcmToken.rawValue
        try await self.sqliteService.async.run { db in
            let query = KV.delete().where { $0.key == key }
            try db.delete(KV.self, query: query)
        }
    }
}
