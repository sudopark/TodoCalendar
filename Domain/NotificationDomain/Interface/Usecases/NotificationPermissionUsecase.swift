//
//  NotificationPermissionUsecase.swift
//  NotificationDomainInterface
//
//  Created by sudo.park on 1/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation

public enum NotificationAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorized
}

public protocol NotificationPermissionUsecase: AnyObject, Sendable {

    func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus

    func requestPermission() async throws -> Bool
}
