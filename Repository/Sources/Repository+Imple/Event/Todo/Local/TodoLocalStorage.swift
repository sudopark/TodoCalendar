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


public enum TodoToggleStateUpdateParamas {
    case idle
    case completing(origin: TodoEvent)
    case reverting
}

public protocol TodoLocalStorage: Sendable { 
    
    func loadAllEvents() async throws -> [TodoEvent]
    func loadTodoEvent(_ eventId: String) async throws -> TodoEvent
    func loadCurrentTodoEvents() async throws -> [TodoEvent]
    func loadTodoEvents(in range: Range<TimeInterval>) async throws -> [TodoEvent]
    func saveTodoEvent(_ todo: TodoEvent) async throws
    func updateTodoEvent(_ todo: TodoEvent) async throws
    func updateTodoEvents(_ todos: [TodoEvent]) async throws
    func loadAllDoneEvents() async throws -> [DoneTodoEvent]
    func saveDoneTodoEvent(_ doneEvent: DoneTodoEvent) async throws
    func removeTodo(_ eventId: String) async throws
    func removeTodos(_ eventids: [String]) async throws
    func removeAll() async throws
    func removeAllDoneEvents() async throws
    func removeTodosWith(tagId: String) async throws -> [String]
    func loadDoneTodos(after cursor: TimeInterval?, size: Int) async throws -> [DoneTodoEvent]
    func loadDoneTodoEvent(doneEventId: String) async throws -> DoneTodoEvent
    func removeDoneTodos(pastThan cursor: TimeInterval) async throws
    func removeDoneTodo(_ doneTodoEventIds: [String]) async throws
    func updateDoneTodos(_ dones: [DoneTodoEvent]) async throws
    func todoToggleState(_ id: String) async throws -> TodoTogglingState
    func updateTodoToggleState(_ id: String, _ params: TodoToggleStateUpdateParamas) async throws
    func loadUncompletedTodos(_ now: Date) async throws -> [TodoEvent]
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
    
    public func loadAllEvents() async throws -> [TodoEvent] {
        let timeQuery = Times.selectAll()
        let eventQuery = Todo.selectAll()
        let todos = try await self.loadTodoEvents(timeQuery, eventQuery)
        return todos
    }
    
    public func loadTodoEvent(_ eventId: String) async throws -> TodoEvent {
        guard let todo = try await self.findTodoEvent(eventId)
        else {
            throw RuntimeError(
                key: LocalErrorKeys.notExists.rawValue,
                "todo :\(eventId) is not exists"
            )
        }
        return todo
    }
    
    private func findTodoEvent(_ eventId: String) async throws -> TodoEvent? {
        let timeQuery = Times.selectAll()
        let eventQuery = Todo.selectAll { $0.uuid == eventId }
        let todos = try await self.loadTodoEvents(timeQuery, eventQuery)
        return todos.first
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
            try db.createTableOrNot(Times.self)
            return try db.load(query, mapping: mapping)
        }
    }
    
    public func loadAllDoneEvents() async throws -> [DoneTodoEvent] {
        let timeQuery = Times.selectAll()
        let doneQuery = Dones.selectAll()
        let query = doneQuery.innerJoin(with: timeQuery, on: { ($0.uuid, $1.eventId) })
        let mapping: (CursorIterator) throws -> DoneTodoEvent = { cursor in
            return try DoneTodoEvent(cursor)
            |> \.eventTime .~ (try? Times.Entity(cursor).eventTime)
        }
        return try await self.sqliteService.async.run([DoneTodoEvent].self) { db in
            try db.createTableOrNot(Times.self)
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
    
    public func removeTodos(_ eventids: [String]) async throws {
        try await self.sqliteService.async.run { db in
            let query = Times.delete().where { $0.eventId.in(eventids) }
            try db.delete(Times.self, query: query)
        }
        try await self.sqliteService.async.run { db in
            let query = Todo.delete().where { $0.uuid.in(eventids) }
            try db.delete(Todo.self, query: query)
        }
    }
    
    public func removeAll() async throws {
        try await self.sqliteService.async.run { try $0.dropTable(Todo.self) }
    }
    
    public func removeAllDoneEvents() async throws {
        try await self.sqliteService.async.run { try $0.dropTable(Dones.self) }
    }
    
    public func removeTodosWith(tagId: String) async throws -> [String] {
        let todoIds = try await self.sqliteService.async.run([String].self) { db in
            let query = Todo.selectSome { [$0.uuid] }.where { $0.eventTagId == tagId }
            return try db.load(query) { cursor -> String in try cursor.next().unwrap() }
        }
        try await self.sqliteService.async.run { db in
            let query = Times.delete().where { $0.eventId.in(todoIds) }
            try db.delete(Times.self, query: query)
        }
        try await self.sqliteService.async.run { db in
            let query = Todo.delete().where { $0.uuid.in(todoIds) }
            try db.delete(Todo.self, query: query)
        }
        return todoIds
    }
}


extension TodoLocalStorageImple {
    
    public func loadDoneTodos(after cursor: TimeInterval?, size: Int) async throws -> [DoneTodoEvent] {
        let dones = try await self.loadDonesTodoWithoutTime(cursor, size: size)
        let timesMap = try await self.loadDoneTodoTimes(dones).asDictionary { $0.eventId }
        return dones.map { done in
            return done |> \.eventTime .~ timesMap[done.uuid]?.eventTime
        }
    }
    
    public func loadDoneTodoEvent(doneEventId: String) async throws -> DoneTodoEvent {
        let timeQuery = Times.selectAll()
        let doneQuery = Dones.selectAll { $0.uuid == doneEventId }
        let query = doneQuery.innerJoin(with: timeQuery, on: { ($0.uuid, $1.eventId) })
        return try await loadDoneEvent(query).unwrap()
    }
    
    private func loadDoneEvent(_ query: JoinQuery<Dones>) async throws -> DoneTodoEvent? {
        let mapping: (CursorIterator) throws -> DoneTodoEvent = { cursor in
            return try DoneTodoEvent(cursor)
            |> \.eventTime .~ (try? Times.Entity(cursor).eventTime)
        }
        return try await self.sqliteService.async.run(DoneTodoEvent?.self) { db in
            try db.createTableOrNot(Times.self)
            return try db.loadOne(query, mapping: mapping)
        }
    }
    
    private func loadDonesTodoWithoutTime(
        _ cursor: TimeInterval?, size: Int
    ) async throws -> [DoneTodoEvent] {
        let query = if let cursor = cursor {
            Dones.selectAll { $0.doneTime < cursor }
                .orderBy(isAscending: false) { $0.doneTime }
                .limit(size)
        } else {
            Dones.selectAll()
                .orderBy(isAscending: false) { $0.doneTime }
                .limit(size)
        }
        let mapping: (CursorIterator) throws -> DoneTodoEvent = {
            return try DoneTodoEvent($0)
        }
        return try await self.sqliteService.async.run { db in
            return try db.load(query, mapping: mapping)
        }
    }
    
    private func loadDoneTodoTimes(_ dones: [DoneTodoEvent]) async throws -> [Times.Entity] {
        let eventIds = dones.map { $0.uuid }
        let query = Times.selectAll { $0.eventId.in(eventIds) }
        let mapping: (CursorIterator) throws -> Times.Entity? = {
            return try? Times.Entity($0)
        }
        return try await self.sqliteService.async.run { db in
            return try db.load(query, mapping: mapping).compactMap { $0 }
        }
    }
    
    public func removeDoneTodos(pastThan cursor: TimeInterval) async throws {
        let dones = try await self.sqliteService.async.run { db in
            let query = Dones.selectAll { $0.doneTime < cursor }
            return try db.load(query, mapping: { try DoneTodoEvent($0) })
        }
        let ids = dones.map { $0.uuid }
        try await self.sqliteService.async.run { db in
            let query = Dones.delete().where { $0.uuid.in(ids) }
            try db.delete(Dones.self, query: query)
        }
        try? await self.sqliteService.async.run { db in
            let query = Times.delete().where { $0.eventId.in(ids) }
            try db.delete(Times.self, query: query)
        }
    }
    
    public func removeDoneTodo(_ doneTodoEventIds: [String]) async throws {
        try await self.sqliteService.async.run { db in
            let query = Dones.delete().where { $0.uuid.in(doneTodoEventIds) }
            try db.delete(Dones.self, query: query)
        }
        try? await self.sqliteService.async.run { db in
            let query = Times.delete().where { $0.eventId.in(doneTodoEventIds) }
            try db.delete(Times.self, query: query)
        }
    }
    
    public func updateDoneTodos(_ dones: [DoneTodoEvent]) async throws {
        try await self.sqliteService.async.run { db in
            let times = dones.map { Times.Entity($0.uuid, $0.eventTime, nil) }
            try db.insert(Times.self, entities: times)
        }
        try await self.sqliteService.async.run { db in
            try db.insert(Dones.self, entities: dones)
        }
    }
    
    private typealias ToggleTable = TodoToggleStateTable
    
    public func todoToggleState(_ id: String) async throws -> TodoTogglingState {
        let state = try await self.loadTodoToggleState(id)?.state
        switch state {
        case .none, .idle:
            let origin = try await self.findTodoEvent(id)
            return .idle(target: try origin.unwrap())
            
        case .completing:
            let pendingOrigin = try await self.loadPendingDoneTodo(id)
            let doneTodo = try await self.findDoneTodoEvent(by: id, pendingOrigin.time)
            return .completing(origin: pendingOrigin, doneId: doneTodo?.uuid)
            
        case .reverting:
            return .reverting
        }
    }
    
    private func loadTodoToggleState(_ id: String) async throws -> ToggleTable.ToggleState? {
        let query = ToggleTable.selectAll { $0.todoId == id }
        let entity = try await self.sqliteService.async.run(ToggleTable.ToggleState?.self) { db in
            try db.createTableOrNot(ToggleTable.self)
            return try db.loadOne(query)
        }
        return entity
    }
    
    private func loadPendingDoneTodo(_ id: String) async throws -> TodoEvent {
        typealias PendingTable = PendingDoneTodoEventTable
        typealias Pending = PendingTable.PendingDoneTodo
        let pending = try await self.sqliteService.async.run(Pending.self) { db in
            let query = PendingTable.selectAll { $0.uuid == id }
            return try db.loadOne(query).unwrap()
        }
        return pending.todoEvent
    }
    
    private func findDoneTodoEvent(
        by todoId: String, _ time: EventTime?
    ) async throws -> DoneTodoEvent? {
        
        let timeQuery = Times.matchingQuery(time)
        let doneQuery = Dones.selectAll { $0.originEventId == todoId }
        let query = doneQuery.innerJoin(with: timeQuery, on: {
            ($0.uuid, $1.eventId)
        })
        return try await self.loadDoneEvent(query)
    }
    
    public func updateTodoToggleState(
        _ id: String, _ params: TodoToggleStateUpdateParamas
    ) async throws {
        
        switch params {
        case .idle:
            try await self.sqliteService.async.run { db in
                let state = ToggleTable.ToggleState(todoId: id, state: .idle)
                try db.insert(ToggleTable.self, entities: [state], shouldReplace: true)
                try db.delete(
                    PendingDoneTodoEventTable.self, 
                    query: PendingDoneTodoEventTable.delete().where { $0.uuid == id }
                )
            }
        case .completing(let origin):
            try await self.sqliteService.async.run { db in
                let pending = PendingDoneTodoEventTable.PendingDoneTodo(todoEvent: origin)
                try db.insert(PendingDoneTodoEventTable.self, entities: [pending], shouldReplace: true)
                let state = ToggleTable.ToggleState(todoId: id, state: .completing)
                try db.insert(ToggleTable.self, entities: [state], shouldReplace: true)
            }
            
        case .reverting:
            try await self.sqliteService.async.run { db in
                let state = ToggleTable.ToggleState(todoId: id, state: .reverting)
                try db.insert(ToggleTable.self, entities: [state], shouldReplace: true)
            }
        }
    }
    
    public func loadUncompletedTodos(_ now: Date) async throws -> [TodoEvent] {
        let timeQuery = Times.selectAll { $0.timeUpperInterval < now.timeIntervalSince1970 }
        let todoQuery = Todo.selectAll()
        return try await self.loadTodoEvents(timeQuery, todoQuery)
    }
}
