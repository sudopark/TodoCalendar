//
//  UserNotificationUsecase.swift
//  Domain
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public protocol UserNotificationUsecase: Sendable {
    
    func register(fcmToken: String) async throws
}


public final class UserNotificationUsecaseImple: UserNotificationUsecase {
    
    private let repository: any UserNotificationRepository
    private let deviceInfoFetchService: any DeviceInfoFetchService
    
    public init(
        repository: any UserNotificationRepository,
        deviceInfoFetchService: any DeviceInfoFetchService
    ) {
        self.repository = repository
        self.deviceInfoFetchService = deviceInfoFetchService
    }
}

extension UserNotificationUsecaseImple {

    public func register(fcmToken: String) async throws {
        let deviceInfo = await self.deviceInfoFetchService.fetchDeviceInfo()
        try await self.repository.register(
            fcmToken: fcmToken, deviceInfo: deviceInfo
        )
    }
}
