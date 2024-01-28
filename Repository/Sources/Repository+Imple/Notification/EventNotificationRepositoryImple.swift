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
        let mapper: EventNotificationTimeOptionMapper? = self.environmentStorage.load(
            forAllDay ? self.defaultNotificationTimeForAllDay : self.defaultNotificationTimeKey
        )
        return mapper?.option
    }
    
    public func saveDefaultNotificationTimeOption(
        forAllday: Bool, option: EventNotificationTimeOption?
    ) {
        let key = forAllday ? self.defaultNotificationTimeForAllDay : self.defaultNotificationTimeKey
        if let value = option {
            let mapper = EventNotificationTimeOptionMapper(option: value)
            self.environmentStorage.update(key, mapper)
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
