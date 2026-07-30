//
//  UNLocalNotificationServiceImple.swift
//  FirstPartyServices
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import UserNotifications
import Prelude
import Optics
import Extensions
import Domain


public final class UNLocalNotificationServiceImple: LocalNotificationService, @unchecked Sendable {

    private let notificationCenter: UNUserNotificationCenter
    public init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }
}

extension UNLocalNotificationServiceImple {

    public func scheduleEventNotification(
        _ params: SingleEventNotificationMakeParams
    ) async throws -> String? {
        let content = UNMutableNotificationContent()
            |> \.title .~ params.eventName
            |> \.body .~ params.eventTimeText

        guard let trigger = params.scheduleTime.trigger(from: Date())
        else { return nil }

        let uuid = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuid, content: content, trigger: trigger)
        try await self.notificationCenter.add(request)
        return uuid
    }

    public func removePendingNotifications(withIdentifiers ids: [String]) {
        self.notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
    }

    public func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus {
        let status = await self.notificationCenter.notificationSettings().authorizationStatus
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

    public func requestAuthorization() async throws -> Bool {
        return try await self.notificationCenter.requestAuthorization(
            options: [.alert, .badge, .sound]
        )
    }
}


private extension SingleEventNotificationMakeParams.ScheduleTime {

    func trigger(from now: Date) -> UNNotificationTrigger? {
        switch self {
        case .at(let time):
            let interval = time - now.timeIntervalSince1970
            guard interval > 0 else { return nil }
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        case .components(let components):
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
    }
}
