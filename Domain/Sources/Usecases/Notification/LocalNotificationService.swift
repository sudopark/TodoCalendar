//
//  LocalNotificationService.swift
//  Domain
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public protocol LocalNotificationService: Sendable {

    /// 이벤트 알림 등록. 스케줄 시각이 이미 지난 경우 등록하지 않고 nil, 등록 시 notification identifier 반환
    func scheduleEventNotification(
        _ params: SingleEventNotificationMakeParams
    ) async throws -> String?

    func removePendingNotifications(withIdentifiers ids: [String])

    func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus

    func requestAuthorization() async throws -> Bool
}
