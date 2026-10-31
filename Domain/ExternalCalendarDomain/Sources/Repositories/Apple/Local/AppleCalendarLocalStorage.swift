//
//  AppleCalendarLocalStorage.swift
//  ExternalCalendarDomain
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import DBInfraInterface
import EventDomainInterface
import ExternalCalendarDomainInterface


// MARK: - AppleCalendarLocalStorage

public protocol AppleCalendarLocalStorage: Sendable {
    func saveCalendarTags(_ tags: [AppleCalendar.Tag]) async throws
    func loadCalendarTags() async throws -> [AppleCalendar.Tag]
    func saveEventOrigins(_ origins: [AppleCalendar.EventOrigin], in period: Range<TimeInterval>) async throws
    func loadEvents(in period: Range<TimeInterval>) async throws -> [AppleCalendar.Event]
    func loadEventOrigin(id: String) async throws -> AppleCalendar.EventOrigin?
    func updateEventOrigin(_ origin: AppleCalendar.EventOrigin) async throws
    func removeEvents(_ eventIds: [String]) async throws
    func resetAll() async throws
}


// MARK: - AppleCalendarLocalStorageImple

public final class AppleCalendarLocalStorageImple: AppleCalendarLocalStorage {

    private let connectionPool: any ExternalCalendarDBConnectionPool
    private let timeStorage: any EventTimeLocalStorage

    public init(
        connectionPool: any ExternalCalendarDBConnectionPool,
        timeStorage: any EventTimeLocalStorage
    ) {
        self.connectionPool = connectionPool
        self.timeStorage = timeStorage
    }

    private func connection() async throws -> SQLiteService {
        return try await connectionPool.connection(serviceId: AppleCalendarService.id)
    }

    private typealias Tags = AppleCalendarTagTable
    private typealias Events = AppleCalendarEventTable
}


// MARK: - tags

extension AppleCalendarLocalStorageImple {

    public func saveCalendarTags(_ tags: [AppleCalendar.Tag]) async throws {
        let connection = try await self.connection()
        try await connection.async.run { db in
            try db.createTableOrNot(Tags.self)
            try db.delete(Tags.self, query: Tags.delete())
            try db.insert(Tags.self, entities: tags.map { Tags.Entity($0) })
        }
    }

    public func loadCalendarTags() async throws -> [AppleCalendar.Tag] {
        let connection = try await self.connection()
        return try await connection.async.run { db in
            try db.createTableOrNot(Tags.self)
            return try db.load(Tags.self, query: Tags.selectAll()).map { $0.asTag() }
        }
    }
}


// MARK: - events

extension AppleCalendarLocalStorageImple {

    public func saveEventOrigins(_ origins: [AppleCalendar.EventOrigin], in period: Range<TimeInterval>) async throws {
        let connection = try await self.connection()

        let periodEventIds = Array(try await self.timeStorage.loadTimes(overlapping: period).keys)
        let oldIds = try await connection.async.run { db -> [String] in
            try db.createTableOrNot(Events.self)
            guard !periodEventIds.isEmpty else { return [] }
            let query = Events.selectSome { [$0.eventId] }.where { $0.eventId.in(periodEventIds) }
            return (try? db.load(query, mapping: { cursor in
                let id: String = try cursor.next().unwrap()
                return id
            })) ?? []
        }

        try await connection.async.run { db in
            if !oldIds.isEmpty {
                let deleteEvents = Events.delete().where { $0.eventId.in(oldIds) }
                try db.delete(Events.self, query: deleteEvents)
            }
            let eventEntities = origins.map { Events.Entity($0) }
            try db.insert(Events.self, entities: eventEntities)
        }
        try await self.timeStorage.removeTimes(eventIds: oldIds)
        let times = Dictionary(origins.map { ($0.eventId, $0.eventTime) }, uniquingKeysWith: { $1 })
        try await self.timeStorage.saveTimes(times)
    }

    public func loadEvents(in period: Range<TimeInterval>) async throws -> [AppleCalendar.Event] {
        let times = try await self.timeStorage.loadTimes(overlapping: period)
        guard !times.isEmpty else { return [] }
        let eventIds = Array(times.keys)
        let query = Events
            .selectSome { [$0.eventId, $0.originalEventId, $0.calendarId, $0.name, $0.isRepeating, $0.location] }
            .where { $0.eventId.in(eventIds) }
            .orderBy("rowid", isAscending: true)

        let mapping: @Sendable (CursorIterator) throws -> AppleCalendar.Event? = { cursor in
            let eventId: String = try cursor.next().unwrap()
            let originalEventId: String = try cursor.next().unwrap()
            let calendarId: String = try cursor.next().unwrap()
            let name: String = try cursor.next().unwrap()
            let isRepeating: Bool = (try? cursor.next().unwrap()) ?? false
            let location: String? = cursor.next()
            guard let time = times[eventId] else { return nil }
            var event = AppleCalendar.Event(
                eventId: eventId,
                originalEventId: originalEventId,
                calendarId: calendarId,
                name: name,
                eventTime: time
            )
            event.isRepeating = isRepeating
            event.location = location
            return event
        }

        let connection = try await self.connection()
        let events = try await connection.async.run { db in
            try db.createTableOrNot(Events.self)
            return try db.load(query, mapping: mapping)
        }
        return events.compactMap { $0 }
    }

    public func loadEventOrigin(id: String) async throws -> AppleCalendar.EventOrigin? {
        let query = Events.selectAll { $0.eventId == id }
        let connection = try await self.connection()
        let entity = try await connection.async.run { db in
            try db.createTableOrNot(Events.self)
            return try db.loadOne(Events.self, query: query)
        }
        guard let entity,
              let time = try await self.timeStorage.loadTime(eventId: id)
        else { return nil }
        return entity.asEventOrigin(eventTime: time)
    }

    public func updateEventOrigin(_ origin: AppleCalendar.EventOrigin) async throws {
        let connection = try await self.connection()
        try await connection.async.run { db in
            try db.createTableOrNot(Events.self)
            try db.insert(Events.self, entities: [Events.Entity(origin)])
        }
        try await self.timeStorage.saveTimes([origin.eventId: origin.eventTime])
    }

    public func removeEvents(_ eventIds: [String]) async throws {
        guard !eventIds.isEmpty else { return }
        let connection = try await self.connection()
        try await connection.async.run { db in
            let deleteEvents = Events.delete().where { $0.eventId.in(eventIds) }
            try db.delete(Events.self, query: deleteEvents)
        }
        try await self.timeStorage.removeTimes(eventIds: eventIds)
    }

    public func resetAll() async throws {
        let connection = try await self.connection()
        try? await self.timeStorage.removeAllTimes()
        try await connection.async.run { db in
            try? db.delete(Events.self, query: Events.delete())
            try? db.delete(Tags.self, query: Tags.delete())
        }
    }

}
