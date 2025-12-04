//
//  UserNotificationRepository.swift
//  Domain
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public protocol UserNotificationRepository: Sendable {
    
    
    func register(_ userId: String, fcmToken: String, deviceInfo: DeviceInfo) async throws
    func unregister(_ userId: String) async throws
}
