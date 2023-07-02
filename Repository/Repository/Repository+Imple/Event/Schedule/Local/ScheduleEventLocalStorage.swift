//
//  ScheduleEventLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import SQLiteService
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
        // 항상 l <= u, L <= U 이고
        // todo의 기간이 l..<u 이며 조회 기간이 L..<U 이라 할때
        // 조회에서 제외되는 조건은 ( l < L && u < L) || ( U <= l && U <= u)
        // 이를 뒤집으면 => (l >= L || u >= L) && ( U > l ||  U > u)
        
        // 1. endtime이 없는경우 null로 저장되기떄문에 l,u >= L 인지 판단하는 로직을 대신해여함
        // 2. l, u < U의 경우는 u가 무한이라면 성립하지 않기 때문에 검사 불필요
        // 1번의 경우 currentTime인 경우도 같이 조회될수있기때문에 filtering 해줘야함 -> upper bound가 null 인 경우는 current Todo 이거나 반복일정이 없는경우만 해당되기 때문에
        // current는 조회에서 제외될것이고 -> lowerInterval 없어서 필터잉
        // 반복일정이 없는 경우는 lower=upper 이기때문에 조건식을 만족못하면 걸러짐
        let timeQuery = Times.selectAll()
            .where {
                $0.lowerInterval >= range.lowerBound
                ||
                $0.upperInterval >= range.lowerBound
                ||
                $0.upperInterval.isNull()
            }
            .where {
                $0.lowerInterval < range.upperBound
                ||
                $0.upperInterval < range.upperBound
            }
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
        self.eventTagId = entity.eventTagId
        self.repeating = entity.repeating
        self.showTurn = entity.showTurn
        self.repeatingTimeToExcludes = entity.excludeTimes |> Set.init
    }
}
