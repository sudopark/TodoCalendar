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
    
    func checkAuthorizationStatus(
        _ resultHandler: @escaping (Result<NotificationAuthorizationStatus, Error>) -> Void
    )
    
    func requestPermission(
        _ resultHandler: @escaping (Result<Bool, Error>) -> Void
    )
}


public final class NotificationPermissionUsecaseImple: NotificationPermissionUsecase, @unchecked Sendable {
    
    private let notificationCenter: UNUserNotificationCenter
    public init() {
        self.notificationCenter = .current()
    }
}


extension NotificationPermissionUsecaseImple {
    
    public func checkAuthorizationStatus(
        _ resultHandler: @escaping (Result<NotificationAuthorizationStatus, Error>) -> Void
    ) {
        self.notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                resultHandler(.success(.notDetermined))
            case .denied:
                resultHandler(.success(.denied))
            case .authorized:
                resultHandler(.success(.authorized))
            case .provisional, .ephemeral:
                resultHandler(.failure(
                    RuntimeError("invalid status")
                ))
            @unknown default:
                fatalError()
            }
        }
    }
    
    public func requestPermission(
        _ resultHandler: @escaping (Result<Bool, Error>
        ) -> Void) {
        
        self.notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { isGrant, error in
            
            if let error {
                resultHandler(.failure(error))
            } else {
                resultHandler(.success(isGrant))
            }
        }
    }
}
