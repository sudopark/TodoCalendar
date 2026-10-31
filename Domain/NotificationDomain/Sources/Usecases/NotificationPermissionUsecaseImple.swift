//
//  NotificationPermissionUsecaseImple.swift
//  NotificationDomain
//
//  Created by sudo.park on 1/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import NotificationDomainInterface

public final class NotificationPermissionUsecaseImple: NotificationPermissionUsecase, @unchecked Sendable {

    private let notificationService: any LocalNotificationService
    public init(
        notificationService: any LocalNotificationService
    ) {
        self.notificationService = notificationService
    }
}


extension NotificationPermissionUsecaseImple {

    public func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus {
        return try await self.notificationService.checkAuthorizationStatus()
    }

    public func requestPermission() async throws -> Bool {
        return try await self.notificationService.requestAuthorization()
    }
}
