//
//  ScheduleEventLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
@preconcurrency import SQLiteService
import Prelude
import Optics
import Domain
import Extensions


public final class ScheduleEventLocalStorage: Sendable {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Schedules = ScheduleEventTable
    private typealias Times = EventTimeTable
}


extension ScheduleEventLocalStorage {
    
    func loadScheduleEvent(_ eventId: String) async throws -> ScheduleEvent {
        let timeQuery = Times.selectAll()
        let eventQuery = Schedules.selectAll { $0.uuid == eventId }
        let schedules = try await self.loadScheduleEvents(timeQuery, eventQuery)
        guard let schedule = schedules.first
        else {
            throw RuntimeError("schedule : \(eventId) is not exists")
        }
        return schedule
    }
    
    func loadScheduleEvents(in range: Range<TimeInterval>) async throws -> [ScheduleEvent] {
        
        let timeQuery = Times.overlapQuery(with: range)
        let eventQuery = Schedules.selectAll()
        return try await self.loadScheduleEvents(timeQuery, eventQuery)
    }
    
    private func loadScheduleEvents(
        _ timeQuery: SelectQuery<Times>,
        _ eventQuery: SelectQuery<Schedules>
    ) async throws -> [ScheduleEvent] {
        
        let query = eventQuery.innerJoin(with: timeQuery, on: { ($0.uuid, $1.eventId) })
        let mapping: (CursorIterator) throws -> ScheduleEvent = { cursor  in
            let entity = try Schedules.Entity(cursor)
            guard let time: EventTime = try? Times.Entity(cursor).eventTime
            else {
                throw RuntimeError("event time is not exists for schedule event")
            }
            return ScheduleEvent(entity, time)
        }
        return try await sqliteService.async.run([ScheduleEvent].self) { db in
            return try db.load(query, mapping: mapping)
        }
    }
}


extension ScheduleEventLocalStorage {
    
    func saveScheduleEvent(_ event: ScheduleEvent) async throws {
        try await self.updateScheduleEvents([event])
    }
    
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {
        try await self.updateScheduleEvents([event])
    }
    
    func updateScheduleEvents(_ events: [ScheduleEvent]) async throws {
        try await self.sqliteService.async.run { db in
            let times = events.map { Times.Entity($0.uuid, $0.time, $0.repeating) }
            try db.insert(Times.self, entities: times)
        }
        try await self.sqliteService.async.run { db in
            let entities = events.map { Schedules.Entity($0) }
            try db.insert(Schedules.self, entities: entities)
        }
    }
    
    func removeScheduleEvent(_ eventId: String) async throws {
        try await self.sqliteService.async.run { db in
            let query = Times.delete().where { $0.eventId == eventId }
            try db.delete(Times.self, query: query)
        }
        try await self.sqliteService.async.run { db in
            let query = Schedules.delete().where { $0.uuid == eventId }
            try db.delete(Schedules.self, query: query)
        }
    }
}


private extension ScheduleEvent {
    
    init(_ entity: ScheduleEventTable.Entity, _ time: EventTime) {
        self.init(uuid: entity.uuid, name: entity.name, time: time)
        self.eventTagId = entity.eventTagId.map { AllEventTagId($0) }
        self.repeating = entity.repeating
        self.showTurn = entity.showTurn
        self.repeatingTimeToExcludes = entity.excludeTimes |> Set.init
        self.notificationOptions = entity.notificationOptions
    }
}
