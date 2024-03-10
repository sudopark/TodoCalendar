//
//  TodoLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
@preconcurrency import SQLiteService
import Prelude
import Optics
import Domain
import Extensions


public protocol TodoLocalStorage: Sendable { 
    
    func loadTodoEvent(_ eventId: String) async throws -> TodoEvent
    func loadCurrentTodoEvents() async throws -> [TodoEvent]
    func loadTodoEvents(in range: Range<TimeInterval>) async throws -> [TodoEvent]
    func saveTodoEvent(_ todo: TodoEvent) async throws
    func updateTodoEvent(_ todo: TodoEvent) async throws
    func updateTodoEvents(_ todos: [TodoEvent]) async throws
    func saveDoneTodoEvent(_ doneEvent: DoneTodoEvent) async throws
    func removeTodo(_ eventId: String) async throws
}

public final class TodoLocalStorageImple: TodoLocalStorage, Sendable {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Todo = TodoEventTable
    private typealias Times = EventTimeTable
    private typealias Dones = DoneTodoEventTable
}


extension TodoLocalStorageImple {
    
    public func loadTodoEvent(_ eventId: String) async throws -> TodoEvent {
        let timeQuery = Times.selectAll()
        let eventQuery = Todo.selectAll { $0.uuid == eventId }
        let todos = try await self.loadTodoEvents(timeQuery, eventQuery)
        guard let todo = todos.first
        else {
            throw RuntimeError("todo :\(eventId) is not exists")
        }
        return todo
    }
    
    public func loadCurrentTodoEvents() async throws -> [TodoEvent] {
        let timeQuery = Times.selectAll { $0.timeType.isNull() }
        let eventQuery = Todo.selectAll()
        return try await self.loadTodoEvents(timeQuery, eventQuery)
    }
    
    public func loadTodoEvents(in range: Range<TimeInterval>) async throws -> [TodoEvent] {
        let timeQuery = Times.overlapQuery(with: range)
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

extension TodoLocalStorageImple {
    
    public func saveTodoEvent(_ todo: TodoEvent) async throws {
        try await self.updateTodoEvents([todo])
    }
    
    public func updateTodoEvent(_ todo: TodoEvent) async throws {
        try await self.updateTodoEvents([todo])
    }
    
    public func updateTodoEvents(_ todos: [TodoEvent]) async throws {
        try await self.sqliteService.async.run { db in
            let times = todos.map { Times.Entity($0.uuid, $0.time, $0.repeating) }
            try db.insert(Times.self, entities: times, shouldReplace: true)
        }
        try await self.sqliteService.async.run { db in
            try db.insert(Todo.self, entities: todos, shouldReplace: true)
        }
    }
    
    public func saveDoneTodoEvent(_ doneEvent: DoneTodoEvent) async throws {
        try await self.sqliteService.async.run { db in
            let time = Times.Entity(doneEvent.uuid, doneEvent.eventTime, nil)
            try db.insert(Times.self, entities: [time])
        }
        try await self.sqliteService.async.run { db in
            try db.insert(Dones.self, entities: [doneEvent])
        }
    }
    
    public func removeTodo(_ eventId: String) async throws {
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
