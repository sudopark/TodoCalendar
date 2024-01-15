//
//  LocalNotificationService.swift
//  Domain
//
//  Created by sudo.park on 1/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import UserNotifications



public protocol LocalNotificationService {
    
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers: [String])
    func notificationAuthorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}


extension UNUserNotificationCenter: LocalNotificationService { 
    
    public func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        return await self.notificationSettings().authorizationStatus
    }
}
