//
//  UserNotificationRepository.swift
//  NotificationDomainInterface
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import KernelUtils


public protocol UserNotificationRepository: Sendable {
    
    
    func register(fcmToken: String, deviceInfo: DeviceInfo) async throws
    func unregister() async throws
}
