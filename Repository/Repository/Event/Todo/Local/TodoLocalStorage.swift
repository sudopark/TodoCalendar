//
//  TodoLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
import SQLiteService
import Domain
import Extensions


public final class TodoLocalStorage: Sendable {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Todo = TodoEventTable
}


extension TodoLocalStorage {
    
    func loadTodoEvent(_ eventId: String) async throws -> TodoEvent {
        throw RuntimeError("not implemented")
    }
    
    func loadCurrentTodoEvents() async throws -> [TodoEvent] {
        throw RuntimeError("not implemented")
    }
    
    func loadTodoEvents(in range: Range<TimeStamp>) async throws -> [TodoEvent] {
        throw RuntimeError("not implemented")
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
        
    }
    
    func saveDoneTodoEvent(_ doneEvent: DoneTodoEvent) async throws {
        
    }
    
    func removeTodo(_ eventId: String) async throws {
        
    }
}
