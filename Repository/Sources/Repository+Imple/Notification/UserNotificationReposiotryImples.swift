//
//  UserNotificationReposiotryImples.swift
//  Repository
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - Empty UserNotificationRepository

public final class EmptyUserNotificationRepositoryImple: UserNotificationRepository {
 
    public init() { }
    
    public func register(_ userId: String, fcmToken: String, deviceInfo: DeviceInfo) async throws { }
    
    public func unregister(_ userId: String) async throws { }
}


// MARK: - Remote UserNotificationRepository

public final class RemoteUserNotificationRepositoryImple: UserNotificationRepository {
    
    private let remoteAPI: any RemoteAPI
    private let environmentStorage: any EnvironmentStorage
    
    public init(
        remoteAPI: any RemoteAPI,
        environmentStorage: any EnvironmentStorage
    ) {
        self.remoteAPI = remoteAPI
        self.environmentStorage = environmentStorage
    }
}


extension RemoteUserNotificationRepositoryImple {
    
    private func fcmKey(_ userId: String) -> String { "fcm_token_\(userId)" }
    
    struct NotificationRegisterResult: Decodable { }
    
    public func register(
        _ userId: String, fcmToken: String, deviceInfo: DeviceInfo
    ) async throws {
        
        let previousToken: String? = self.environmentStorage.load(
            self.fcmKey(userId)
        )
        
        guard previousToken != fcmToken else { return }
        
        let endpoint = UserAPIEndpoint.notification
        var payload: [String: Any] = [
            "fcm_token": fcmToken
        ]
        payload["device_model"] = deviceInfo.deviceModel
        
        let _: NotificationRegisterResult = try await self.remoteAPI.request(
            .put, endpoint, parameters: payload
        )
        
        self.environmentStorage.update(self.fcmKey(userId), fcmToken)
    }
    
    public func unregister(_ userId: String) async throws {
        
        typealias UnregisterResult = NotificationRegisterResult
        
        let endpoint = UserAPIEndpoint.notification
        
        let _: UnregisterResult = try await self.remoteAPI.request(
            .delete, endpoint
        )
        self.environmentStorage.remove(self.fcmKey(userId))
    }
}
