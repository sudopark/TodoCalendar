//
//  EventNotificationRepository.swift
//  Domain
//
//  Created by sudo.park on 1/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation

public protocol EventNotificationRepository: AnyObject, Sendable {
    
    func loadDefaultNotificationTimeOption(forAllDay: Bool) -> EventNotificationTimeOption?
    func saveDefaultNotificationTimeOption(
        forAllday: Bool,
        option: EventNotificationTimeOption?
    )
    func removeAllSavedNotificationId(of eventIds: [String]) async throws -> [String]
    func batchSaveNotificationId(_ eventIdNotificationIdMap: [String: [String]]) async throws
}
