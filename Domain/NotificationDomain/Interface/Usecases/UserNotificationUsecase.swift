//
//  UserNotificationUsecase.swift
//  NotificationDomainInterface
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation

public protocol UserNotificationUsecase: Sendable {
    
    func register(fcmToken: String) async throws
}
