//
//  StubLocalNotificationService.swift
//  Domain
//
//  Created by sudo.park on 1/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import UserNotifications

@testable import Domain


final class StubLocalNotificationService: LocalNotificationService {
    
    var didAddNotificationRequest: UNNotificationRequest?
    func add(_ request: UNNotificationRequest) async throws {
        self.didAddNotificationRequest = request
    }
    
    var didRemovePendingNotificationRequestIdentifiers: [String]?
    func removePendingNotificationRequests(withIdentifiers: [String]) {
        self.didRemovePendingNotificationRequestIdentifiers = withIdentifiers
    }
    
    var stubAuthorizeStatus: UNAuthorizationStatus?
    func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        return stubAuthorizeStatus ?? .notDetermined
    }
    
    var stubAuthorizationRequestResult: Result<Bool, any Error> = .success(true)
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        switch self.stubAuthorizationRequestResult {
        case .success(let flag):
            return flag
        case .failure(let error):
            throw error
        }
    }
}
