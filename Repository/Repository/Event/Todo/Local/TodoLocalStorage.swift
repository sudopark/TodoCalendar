//
//  TodoLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
import SQLiteService
import Prelude
import Optics
import Domain
import Extensions


public final class TodoLocalStorage: Sendable {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Todo = TodoEventTable
    private typealias Times = EventTimeTable
    private typealias Dones = DoneTodoEventTable
}


extension TodoLocalStorage {
    
    func loadTodoEvent(_ eventId: String) async throws -> TodoEvent {
        let timeQuery = Times.selectAll()
        let eventQuery = Todo.selectAll { $0.uuid == eventId }
        let todos = try await self.loadTodoEvents(timeQuery, eventQuery)
        guard let todo = todos.first
        else {
            throw RuntimeError("todo :\(eventId) is not exists")
        }
        return todo
    }
    
    func loadCurrentTodoEvents() async throws -> [TodoEvent] {
        let timeQuery = Times.selectAll { $0.timeType.isNull() }
        let eventQuery = Todo.selectAll()
        return try await self.loadTodoEvents(timeQuery, eventQuery)
    }
    
    func loadTodoEvents(in range: Range<TimeStamp>) async throws -> [TodoEvent] {
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
                $0.lowerInterval >= range.lowerBound.utcTimeInterval
                ||
                $0.upperInterval >= range.lowerBound.utcTimeInterval
                ||
                $0.upperInterval.isNull()
            }
            .where {
                $0.lowerInterval < range.upperBound.utcTimeInterval
                ||
                $0.upperInterval < range.upperBound.utcTimeInterval
            }
        let eventQuery = Todo.selectAll()
        return try await self.loadTodoEvents(timeQuery, eventQuery)
    }
    
    private func loadTodoEvents(
        _ timeQuery: SelectQuery<Times>,
        _ eventQuery: SelectQuery<Todo>
    ) async throws -> [TodoEvent] {
        
        let query = eventQuery.innerJoin(with: timeQuery, on: { ($0.uuid, $1.eventId) })
        let mapping: (CursorIterator) throws -> TodoEvent = { cursor in
            return try TodoEvent(cursor)
                |> \.time .~ (try? Times.Entity(cursor).eventTime)
        }
        return try await self.sqliteService.async.run([TodoEvent].self) { db in
            return try db.load(query, mapping: mapping)
        }
    }
}

extension TodoLocalStorage {
    
    func saveTodoEvent(_ todo: TodoEvent) async throws {
        try await self.updateTodoEvents([todo])
    }
    
    func updateTodoEvent(_ todo: TodoEvent) async throws {
        try await self.updateTodoEvents([todo])
    }
    
    func updateTodoEvents(_ todos: [TodoEvent]) async throws {
        try await self.sqliteService.async.run { db in
            let times = todos.map { Times.Entity($0.uuid, $0.time, $0.repeating) }
            try db.insert(Times.self, entities: times, shouldReplace: true)
        }
        try await self.sqliteService.async.run { db in
            try db.insert(Todo.self, entities: todos, shouldReplace: true)
        }
    }
    
    func saveDoneTodoEvent(_ doneEvent: DoneTodoEvent) async throws {
        try await self.sqliteService.async.run { db in
            let time = Times.Entity(doneEvent.uuid, doneEvent.eventTime, nil)
            try db.insert(Times.self, entities: [time])
        }
        try await self.sqliteService.async.run { db in
            try db.insert(Dones.self, entities: [doneEvent])
        }
    }
    
    func removeTodo(_ eventId: String) async throws {
        try await self.sqliteService.async.run { db in
            let query = Times.delete().where { $0.eventId == eventId }
            try db.delete(Times.self, query: query)
        }
        try await self.sqliteService.async.run { db in
            let query = Todo.delete().where { $0.uuid == eventId }
            try db.delete(Todo.self, query: query)
        }
    }
}
