//
//  TodoUploadDecorateRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


public final class TodoUploadDecorateRepositoryImple: TodoEventRepository {
    
    private let localRepository: TodoLocalRepositoryImple
    private let eventUploadService: any EventUploadService
    
    public init(
        localRepository: TodoLocalRepositoryImple,
        eventUploadService: any EventUploadService
    ) {
        self.localRepository = localRepository
        self.eventUploadService = eventUploadService
    }
}

extension TodoUploadDecorateRepositoryImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        
        let newTodo = try await self.localRepository.makeTodoEvent(params)
        try await self.eventUploadService.append(
            .init(dataType: .todo, uuid: newTodo.uuid, isRemovingTask: false)
        )
        return newTodo
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        let updated = try await self.localRepository.updateTodoEvent(eventId, params)
        try await self.eventUploadService.append(
            .init(dataType: .todo, uuid: updated.uuid, isRemovingTask: false)
        )
        return updated
    }
}

extension TodoUploadDecorateRepositoryImple {
    
    public func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        
        let result = try await self.localRepository.completeTodo(eventId)
        
        if let next = result.nextRepeatingTodoEvent {
            try await self.eventUploadService.append([
                .init(dataType: .todo, uuid: next.uuid, isRemovingTask: false),
                .init(dataType: .doneTodo, uuid: result.doneEvent.uuid, isRemovingTask: false)
            ])
        } else {
            try await self.eventUploadService.append([
                .init(dataType: .todo, uuid: eventId, isRemovingTask: true),
                .init(dataType: .doneTodo, uuid: result.doneEvent.uuid, isRemovingTask: false)
            ])
        }
        return result
    }
    
    public func replaceRepeatingTodo(current eventId: String, to newParams: TodoMakeParams) async throws -> ReplaceRepeatingTodoEventResult {
        
        let result = try await self.localRepository.replaceRepeatingTodo(current: eventId, to: newParams)
        
        if let next = result.nextRepeatingTodoEvent {
            try await self.eventUploadService.append(
                .init(dataType: .todo, uuid: next.uuid, isRemovingTask: false)
            )
        } else {
            try await self.eventUploadService.append(
                .init(dataType: .todo, uuid: eventId, isRemovingTask: true)
            )
        }
        
        try await self.eventUploadService.append(
            .init(dataType: .todo, uuid: result.newTodoEvent.uuid, isRemovingTask: false)
        )
        
        return result
    }
}

extension TodoUploadDecorateRepositoryImple {
    
    public func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult {
        let result = try await self.localRepository.removeTodo(eventId, onlyThisTime: onlyThisTime)
        if let next = result.nextRepeatingTodo {
            try await self.eventUploadService.append(
                .init(dataType: .todo, uuid: next.uuid, isRemovingTask: false)
            )
        } else {
            try await self.eventUploadService.append(
                .init(dataType: .todo, uuid: eventId, isRemovingTask: true)
            )
        }
        return result
    }
    
    public func skipRepeatingTodo(_ todoId: String) async throws -> TodoEvent {
        let event = try await self.localRepository.skipRepeatingTodo(todoId)
        try await self.eventUploadService.append(
            .init(dataType: .todo, uuid: event.uuid, isRemovingTask: false)
        )
        return event
    }
}

extension TodoUploadDecorateRepositoryImple {
    
    public func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], any Error> {
        return self.localRepository.loadCurrentTodoEvents()
    }
    
    public func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error> {
        return self.localRepository.loadTodoEvents(in: range)
    }
    
    public func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error> {
        return self.localRepository.todoEvent(id)
    }
    
    public func loadUncompletedTodos() -> AnyPublisher<[TodoEvent], any Error> {
        return self.localRepository.loadUncompletedTodos()
    }
}

extension TodoUploadDecorateRepositoryImple {
    
    public func loadDoneTodoEvents(_ params: DoneTodoLoadPagingParams) async throws -> [DoneTodoEvent] {
        return try await self.localRepository.loadDoneTodoEvents(params)
    }
 
    public func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws {
        return try await self.localRepository.removeDoneTodos(scope)
    }
    
    public func revertDoneTodo(_ doneTodoId: String) async throws -> TodoEvent {
        let revert = try await self.localRepository.revertDoneTodo(doneTodoId)
        try await self.eventUploadService.append(
            .init(dataType: .todo, uuid: revert.uuid, isRemovingTask: false)
        )
        return revert
    }
    
    public func toggleTodo(_ todoId: String) async throws -> TodoToggleResult? {
        try await self.localRepository.toggleTodo(todoId)
    }
}
