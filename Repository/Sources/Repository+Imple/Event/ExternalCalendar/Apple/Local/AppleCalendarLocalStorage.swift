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
    func saveEvents(_ events: [AppleCalendar.Event], in period: Range<TimeInterval>) async throws
    func loadEvents(in period: Range<TimeInterval>) async throws -> [AppleCalendar.Event]
    func loadEvent(id: String) async throws -> AppleCalendar.Event?
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

    public func saveEvents(_ events: [AppleCalendar.Event], in period: Range<TimeInterval>) async throws {
        let connection = try await self.connection()

        // 기존 period 내 이벤트 ID 조회 후 삭제
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
            let eventEntities = events.map { Events.Entity($0) }
            try db.insert(Events.self, entities: eventEntities)
            let timeEntities = events.map { Times.Entity($0.eventId, $0.eventTime, nil) }
            try db.insert(Times.self, entities: timeEntities)
        }
    }

    public func loadEvents(in period: Range<TimeInterval>) async throws -> [AppleCalendar.Event] {
        let timeQuery = Times.overlapQuery(with: period)
        let query = Events.selectAll().innerJoin(with: timeQuery, on: { ($0.eventId, $1.eventId) })

        let mapping: (CursorIterator) throws -> AppleCalendar.Event = { cursor in
            let event = try Events.Entity(cursor)
            let time = try Times.Entity(cursor).eventTime.unwrap()
            return AppleCalendar.Event(
                eventId: event.eventId,
                originalEventId: event.originalEventId,
                calendarId: event.calendarId,
                name: event.name,
                eventTime: time,
                isRepeating: event.isRepeating,
                location: event.location,
                url: event.url,
                notes: event.notes
            )
        }

        let connection = try await self.connection()
        return try await connection.async.run { db in
            try db.createTableOrNot(Events.self)
            try db.createTableOrNot(Times.self)
            return try db.load(query, mapping: mapping)
        }
    }

    public func loadEvent(id: String) async throws -> AppleCalendar.Event? {
        let query = Events
            .selectAll()
            .innerJoin(with: Times.selectAll { $0.eventId == id }, on: { ($0.eventId, $1.eventId) })

        let mapping: (CursorIterator) throws -> AppleCalendar.Event = { cursor in
            let event = try Events.Entity(cursor)
            let time = try Times.Entity(cursor).eventTime.unwrap()
            return AppleCalendar.Event(
                eventId: event.eventId,
                originalEventId: event.originalEventId,
                calendarId: event.calendarId,
                name: event.name,
                eventTime: time,
                isRepeating: event.isRepeating,
                location: event.location,
                url: event.url,
                notes: event.notes
            )
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
