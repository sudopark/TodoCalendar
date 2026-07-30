//
//  StubLocalNotificationService.swift
//  Domain
//
//  Created by sudo.park on 1/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions
import Domain


final class StubLocalNotificationService: LocalNotificationService, @unchecked Sendable {

    var didScheduledNotificationParams: [SingleEventNotificationMakeParams] = []
    var didNotificationScheduled: ((SingleEventNotificationMakeParams) -> Void)?
    func scheduleEventNotification(
        _ params: SingleEventNotificationMakeParams
    ) async throws -> String? {
        // 기존 UN 트리거 변환과 동일 시맨틱: 과거 .at 시각이면 미등록(nil)
        if case .at(let time) = params.scheduleTime, time - Date().timeIntervalSince1970 <= 0 {
            return nil
        }
        self.didScheduledNotificationParams.append(params)
        self.didNotificationScheduled?(params)
        return UUID().uuidString
    }

    var didRemovePendingNotificationIds: [String]?
    var didPendingNotificationsRemoved: (([String]) -> Void)?
    func removePendingNotifications(withIdentifiers ids: [String]) {
        self.didRemovePendingNotificationIds = ids
        self.didPendingNotificationsRemoved?(ids)
    }

    var stubAuthorizeStatus: NotificationAuthorizationStatus?
    var shouldFailCheckAuthorizationStatus: Bool = false
    func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus {
        if self.shouldFailCheckAuthorizationStatus {
            throw RuntimeError("invalid status")
        }
        return self.stubAuthorizeStatus ?? .notDetermined
    }

    var stubAuthorizationRequestResult: Result<Bool, any Error> = .success(true)
    func requestAuthorization() async throws -> Bool {
        return try self.stubAuthorizationRequestResult.get()
    }
}
