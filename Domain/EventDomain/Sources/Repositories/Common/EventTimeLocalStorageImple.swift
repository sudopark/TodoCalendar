//
//  EventTimeLocalStorageImple.swift
//  EventDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Extensions
import DBInfraInterface
import EventDomainInterface


public final class EventTimeLocalStorageImple: EventTimeLocalStorage {

    private let connectionPool: any ExternalCalendarDBConnectionPool
    private let serviceId: String

    public init(
        connectionPool: any ExternalCalendarDBConnectionPool,
        serviceId: String
    ) {
        self.connectionPool = connectionPool
        self.serviceId = serviceId
    }

    private typealias Times = EventTimeTable

    private func run<T: Sendable>(_ action: @escaping @Sendable (DataBase) throws -> T) async throws -> T {
        let connection = try await self.connectionPool.connection(serviceId: self.serviceId)
        return try await connection.async.run { db in
            try db.createTableOrNot(Times.self)
            return try action(db)
        }
    }
}


extension EventTimeLocalStorageImple {

    public func loadTimes(overlapping range: Range<TimeInterval>) async throws -> [String: EventTime] {
        let query = Times.overlapQuery(with: range)
        let entities = try await self.run { try $0.load(Times.self, query: query) }
        return entities.reduce(into: [String: EventTime]()) { acc, entity in
            acc[entity.eventId] = entity.eventTime
        }
    }

    public func loadTime(eventId: String) async throws -> EventTime? {
        let query = Times.selectAll { $0.eventId == eventId }
        let entity = try await self.run { try $0.loadOne(Times.self, query: query) }
        return entity?.eventTime
    }

    public func saveTimes(_ times: [String: EventTime]) async throws {
        guard !times.isEmpty else { return }
        let entities = times.map { Times.Entity($0.key, $0.value, nil) }
        try await self.run { try $0.insert(Times.self, entities: entities) }
    }

    public func removeTimes(eventIds: [String]) async throws {
        guard !eventIds.isEmpty else { return }
        let query = Times.delete().where { $0.eventId.in(eventIds) }
        try await self.run { try $0.delete(Times.self, query: query) }
    }

    public func removeAllTimes() async throws {
        try await self.run { try $0.delete(Times.self, query: Times.delete()) }
    }
}
