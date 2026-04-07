//
//  AppleCalendarLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService


// MARK: - AppleCalendarLocalStorage

public protocol AppleCalendarLocalStorage: Sendable {
    func saveCalendarTags(_ tags: [AppleCalendar.Tag]) async throws
    func loadCalendarTags() async throws -> [AppleCalendar.Tag]
    func saveEventOrigins(_ origins: [AppleCalendar.EventOrigin], in period: Range<TimeInterval>) async throws
    func loadEvents(in period: Range<TimeInterval>) async throws -> [AppleCalendar.Event]
    func loadEventOrigin(id: String) async throws -> AppleCalendar.EventOrigin?
    func resetAll() async throws
}


// MARK: - AppleCalendarLocalStorageImple

public final class AppleCalendarLocalStorageImple: AppleCalendarLocalStorage {

    private let connectionPool: any ExternalCalendarDBConnectionPool

    public init(connectionPool: any ExternalCalendarDBConnectionPool) {
        self.connectionPool = connectionPool
    }

    private func connection() async throws -> SQLiteService {
        return try await connectionPool.connection(serviceId: AppleCalendarService.id)
    }

    private typealias Tags = AppleCalendarTagTable
    private typealias Events = AppleCalendarEventTable
    private typealias Times = EventTimeTable
}


// MARK: - tags

extension AppleCalendarLocalStorageImple {

    public func saveCalendarTags(_ tags: [AppleCalendar.Tag]) async throws {
        let connection = try await self.connection()
        try await connection.async.run { db in
            try db.createTableOrNot(Tags.self)
            try db.delete(Tags.self, query: Tags.delete())
            try db.insert(Tags.self, entities: tags)
        }
    }

    public func loadCalendarTags() async throws -> [AppleCalendar.Tag] {
        let connection = try await self.connection()
        return try await connection.async.run { db in
            try db.createTableOrNot(Tags.self)
            return try db.load(Tags.self, query: Tags.selectAll())
        }
    }
}


// MARK: - events

extension AppleCalendarLocalStorageImple {

    public func saveEventOrigins(_ origins: [AppleCalendar.EventOrigin], in period: Range<TimeInterval>) async throws {
        let connection = try await self.connection()

        let oldIds = try await connection.async.run { db -> [String] in
            try db.createTableOrNot(Events.self)
            try db.createTableOrNot(Times.self)
            let timeQuery = Times.overlapQuery(with: period)
            let joinQuery = Events
                .selectSome { [$0.eventId] }
                .innerJoin(with: timeQuery, on: { ($0.eventId, $1.eventId) })
            return (try? db.load(joinQuery, mapping: { cursor in
                let id: String = try cursor.next().unwrap()
                return id
            })) ?? []
        }

        try await connection.async.run { db in
            if !oldIds.isEmpty {
                let deleteEvents = Events.delete().where { $0.eventId.in(oldIds) }
                try db.delete(Events.self, query: deleteEvents)
                let deleteTimes = Times.delete().where { $0.eventId.in(oldIds) }
                try db.delete(Times.self, query: deleteTimes)
            }
            let eventEntities = origins.map { Events.Entity($0) }
            try db.insert(Events.self, entities: eventEntities)
            let timeEntities = origins.map { Times.Entity($0.eventId, $0.eventTime, nil) }
            try db.insert(Times.self, entities: timeEntities)
        }
    }

    public func loadEvents(in period: Range<TimeInterval>) async throws -> [AppleCalendar.Event] {
        let timeQuery = Times.overlapQuery(with: period)
        let query = Events
            .selectSome { [$0.eventId, $0.originalEventId, $0.calendarId, $0.name, $0.isRepeating, $0.location] }
            .innerJoin(with: timeQuery, on: { ($0.eventId, $1.eventId) })

        let mapping: (CursorIterator) throws -> AppleCalendar.Event = { cursor in
            let eventId: String = try cursor.next().unwrap()
            let originalEventId: String = try cursor.next().unwrap()
            let calendarId: String = try cursor.next().unwrap()
            let name: String = try cursor.next().unwrap()
            let isRepeating: Bool = (try? cursor.next().unwrap()) ?? false
            let location: String? = cursor.next()
            let time = try Times.Entity(cursor).eventTime.unwrap()
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
        return try await connection.async.run { db in
            try db.createTableOrNot(Events.self)
            try db.createTableOrNot(Times.self)
            return try db.load(query, mapping: mapping)
        }
    }

    public func loadEventOrigin(id: String) async throws -> AppleCalendar.EventOrigin? {
        let query = Events
            .selectAll()
            .innerJoin(with: Times.selectAll { $0.eventId == id }, on: { ($0.eventId, $1.eventId) })

        let mapping: (CursorIterator) throws -> AppleCalendar.EventOrigin = { cursor in
            let entity = try Events.Entity(cursor)
            let time = try Times.Entity(cursor).eventTime.unwrap()
            return entity.asEventOrigin(eventTime: time)
        }

        let connection = try await self.connection()
        return try await connection.async.run { db in
            try db.createTableOrNot(Events.self)
            try db.createTableOrNot(Times.self)
            return try db.load(query, mapping: mapping).first
        }
    }

    public func resetAll() async throws {
        let connection = try await self.connection()
        try await connection.async.run { db in
            try? db.delete(Times.self, query: Times.delete())
            try? db.delete(Events.self, query: Events.delete())
            try? db.delete(Tags.self, query: Tags.delete())
        }
    }

}
