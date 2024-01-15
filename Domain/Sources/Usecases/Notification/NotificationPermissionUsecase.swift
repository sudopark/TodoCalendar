//
//  NotificationPermissionUsecase.swift
//  Domain
//
//  Created by sudo.park on 1/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import UserNotifications
import Extensions

public enum NotificationAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorized
}

public protocol NotificationPermissionUsecase: AnyObject, Sendable {
    
    func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus
    
    func requestPermission() async throws -> Bool
}


public final class NotificationPermissionUsecaseImple: NotificationPermissionUsecase, @unchecked Sendable {
    
    private let notificationService: any LocalNotificationService
    public init(
        notificationService: any LocalNotificationService = UNUserNotificationCenter.current()
    ) {
        self.notificationService = notificationService
    }
}


extension NotificationPermissionUsecaseImple {
    
    public func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus {
        let status = await self.notificationService.notificationAuthorizationStatus()
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional, .ephemeral:
            throw RuntimeError("invalid status - \(status)")
        @unknown default:
            fatalError()
        }
    }
    
    public func requestPermission() async throws -> Bool {
        
        return try await self.notificationService.requestAuthorization(
            options: [.alert, .badge, .sound]
        )
    }
}
