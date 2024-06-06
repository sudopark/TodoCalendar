//
//  TodoLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/05/20.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions


public final class TodoLocalRepositoryImple: TodoEventRepository, Sendable {
    
    private let localStorage: any TodoLocalStorage
    private let environmentStorage: any EnvironmentStorage
    public init(
        localStorage: any TodoLocalStorage,
        environmentStorage: any EnvironmentStorage
    ) {
        self.localStorage = localStorage
        self.environmentStorage = environmentStorage
    }
}


// MARK: - make

extension TodoLocalRepositoryImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        guard let newTodo = TodoEvent(params)
        else {
            throw RuntimeError("invalid parameter")
        }
        try await self.localStorage.saveTodoEvent(newTodo)
        return newTodo
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        let origin = try await self.localStorage.loadTodoEvent(eventId)
        let updated = origin.apply(params)
        try await self.localStorage.updateTodoEvent(updated)
        return updated
    }
}


// MARK: - complete

extension TodoLocalRepositoryImple {
    
    public func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        
        let origin = try await self.localStorage.loadTodoEvent(eventId)
        try await self.localStorage.removeTodo(eventId)
        
        let doneEvent = DoneTodoEvent(origin)
        try? await self.localStorage.saveDoneTodoEvent(doneEvent)
        
        let nextTodo = try await self.replaceTodoNextEventTimeIfIsRepeating(origin)
        
        return .init(doneEvent: doneEvent, nextRepeatingTodoEvent: nextTodo)
    }
    
    public func replaceRepeatingTodo(current eventId: String, to newParams: TodoMakeParams) async throws -> ReplaceRepeatingTodoEventResult {
        
        let origin = try await self.localStorage.loadTodoEvent(eventId)
        try await self.localStorage.removeTodo(eventId)
        
        let newTodo = try await self.makeTodoEvent(newParams)
        let nextTodo = try await self.replaceTodoNextEventTimeIfIsRepeating(origin)
        
        return ReplaceRepeatingTodoEventResult(newTodoEvent: newTodo)
            |> \.nextRepeatingTodoEvent .~ nextTodo
    }
    
    private func replaceTodoNextEventTimeIfIsRepeating(_ origin: TodoEvent) async throws -> TodoEvent? {
        guard let repeating = origin.repeating,
              let time = origin.time,
              let nextEventTime = EventRepeatTimeEnumerator(repeating.repeatOption)?.nextEventTime(from: time, until: repeating.repeatingEndTime)
        else { return nil }
        
        let nextTodo = origin |> \.time .~ nextEventTime
        try await self.localStorage.updateTodoEvent(nextTodo)
        return origin |> \.time .~ nextEventTime
    }
}


// MARK: - remove

extension TodoLocalRepositoryImple {
    
    public func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult {
        let origin = try await self.localStorage.loadTodoEvent(eventId)
        
        try await self.localStorage.removeTodo(eventId)
        
        let next: TodoEvent? = onlyThisTime
            ? try await self.replaceTodoNextEventTimeIfIsRepeating(origin)
            : nil
        
        return RemoveTodoResult() |> \.nextRepeatingTodo .~ next
    }
}


extension TodoLocalRepositoryImple {
    
    public func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadCurrentTodoEvents()
        }
        .eraseToAnyPublisher()
    }
    
    public func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadTodoEvents(in: range)
        }
        .eraseToAnyPublisher()
    }
    
    public func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadTodoEvent(id)
        }
        .eraseToAnyPublisher()
    }
}


extension TodoLocalRepositoryImple {
    
    public func loadDoneTodoEvents(
        _ params: DoneTodoLoadPagingParams
    ) async throws -> [DoneTodoEvent] {
        return try await self.localStorage.loadDoneTodos(
            after: params.cursorAfter, size: params.size
        )
    }
    
    public func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws {
        switch scope {
        case .all:
            return try await self.localStorage.removeAllDoneEvents()
        case .pastThan(let time):
            return try await localStorage.removeDoneTodos(pastThan: time)
        }
    }
    
    public func revertDoneTodo(_ doneTodoId: String) async throws -> TodoEvent {
        let done = try await self.localStorage.loadDoneTodoEvent(doneEventId: doneTodoId)
        let params = TodoMakeParams()
            |> \.name .~ done.name
            |> \.eventTagId .~ done.eventTagId
            |> \.time .~ done.eventTime
            |> \.notificationOptions .~ pure(done.notificationOptions)
        guard let revertTodo = TodoEvent(params)
        else {
            throw RuntimeError("invalid params")
        }
        try await self.localStorage.saveTodoEvent(revertTodo)
        try await self.localStorage.removeDoneTodo([doneTodoId])
        return revertTodo
    }
    
    public func toggleTodo(
        _ todoId: String,
        _ eventTime: EventTime?
    ) async throws -> TodoToggleResult {
        
        if let doneTodo = try await self.localStorage.findDoneTodoEvent(by: todoId, eventTime) {
            let reverted = try await self.revertDoneTodo(doneTodo.uuid)
            return .reverted(reverted)
        } else {
            let completeResult = try await self.completeTodo(todoId)
            return .completed(completeResult.doneEvent)
        }
    }
}
