//
//  EventNotificationRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 1/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
@preconcurrency import SQLiteService
import Domain
import Extensions


public final class EventNotificationRepositoryImple: EventNotificationRepository {
    
    private let sqliteService: SQLiteService
    private let environmentStorage: any EnvironmentStorage
    
    public init(
        sqliteService: SQLiteService,
        environmentStorage: any EnvironmentStorage
    ) {
        self.sqliteService = sqliteService
        self.environmentStorage = environmentStorage
    }
    
    private typealias Ids = EventNotificationIdTable
    private var defaultNotificationTimeKey: String { "default_event_notification_time" }
    private var defaultNotificationTimeForAllDay: String { "default_allday_event_notification_time" }
}


extension EventNotificationRepositoryImple {
    
    public func loadDefaultNotificationTimeOption(
        forAllDay: Bool
    ) -> EventNotificationTimeOption? {
        return self.environmentStorage.load(
            forAllDay ? self.defaultNotificationTimeForAllDay : self.defaultNotificationTimeKey
        )
    }
    
    public func saveDefaultNotificationTimeOption(
        forAllday: Bool, option: EventNotificationTimeOption?
    ) {
        let key = forAllday ? self.defaultNotificationTimeForAllDay : self.defaultNotificationTimeKey
        if let value = option {
            self.environmentStorage.update(key, value)
        } else {
            self.environmentStorage.remove(key)
        }
    }
    
    public func removeAllSavedNotificationId(of eventIds: [String]) async throws -> [String] {
        let entities = try await self.sqliteService.async.run {
            let query = Ids.selectAll { $0.eventId.in(eventIds) }
            return try $0.load(Ids.self, query: query)
        }
        try await self.sqliteService.async.run {
            let query = Ids.delete().where { $0.eventId.in(eventIds) }
            try $0.delete(Ids.self, query: query)
        }
        return entities.map { $0.notificationReqId }
    }
    
    public func batchSaveNotificationId(_ eventIdNotificationIdMap: [String: [String]]) async throws {
        try await self.sqliteService.async.run {
            let entities = eventIdNotificationIdMap.flatMap { pair in
                return pair.value.map { Ids.Entity(pair.key, $0) }
            }
            try $0.insert(Ids.self, entities: entities)
        }
    }
}


extension EventNotificationTimeOption: Codable {
    
    private var typeText: String {
        switch self {
        case .atTime: return "at_time"
        case .before: return "before"
        case .allDay9AM: return "allDay9AM"
        case .allDay12AM: return "allDay12AM"
        case .allDay9AMBefore: return "allDay9AMBefore"
        }
    }
    
    private var beforeSeconds: TimeInterval? {
        switch self {
        case .before(let seconds), .allDay9AMBefore(let seconds): return seconds
        default: return nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case typeText = "type_text"
        case beforeSeconds = "before_seconds"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeText = try container.decode(String.self, forKey: .typeText)
        switch typeText {
        case "at_time":
            self = .atTime
            
        case "before":
            let seconds = try container.decode(Double.self, forKey: .beforeSeconds)
            self = .before(seconds: seconds)
            
        case "allDay9AM":
            self = .allDay9AM
            
        case "allDay12AM":
            self = .allDay12AM
            
        case "allDay9AMBefore":
            let seconds = try container.decode(Double.self, forKey: .beforeSeconds)
            self = .allDay9AMBefore(seconds: seconds)
            
        default:
            throw RuntimeError("invalid value")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.typeText, forKey: .typeText)
        try? container.encode(self.beforeSeconds, forKey: .beforeSeconds)
    }
}
