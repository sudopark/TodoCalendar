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
        let updated = switch params.editMethod {
            case .put: origin.apply(params)
            case .patch: origin.applyIfNotNil(params)
        }
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
        
        let nextTodo = try? await self.replaceTodoNextEventTimeIfIsRepeating(origin)
        
        let result = CompleteTodoResult(
            doneEvent: doneEvent,
            nextRepeatingTodoEvent: nextTodo
        )
        let doneTodoDetail = try? await self.localStorage.copyTodoDetail(eventId, to: doneEvent.uuid)
        
        if nextTodo == nil {
            try? await localStorage.removeTodoDetail(eventId)
        }
        return result |> \.doneTodoEventDetail .~ doneTodoDetail
    }
    
    public func replaceRepeatingTodo(current eventId: String, to newParams: TodoMakeParams) async throws -> ReplaceRepeatingTodoEventResult {
        
        let origin = try await self.localStorage.loadTodoEvent(eventId)
        try await self.localStorage.removeTodo(eventId)
        
        let newTodo = try await self.makeTodoEvent(newParams)
        let nextTodo = try? await self.replaceTodoNextEventTimeIfIsRepeating(origin)
        
        return ReplaceRepeatingTodoEventResult(newTodoEvent: newTodo)
            |> \.nextRepeatingTodoEvent .~ nextTodo
    }
    
    private func replaceTodoNextEventTimeIfIsRepeating(_ origin: TodoEvent) async throws -> TodoEvent {
        guard let repeating = origin.repeating,
              let time = origin.time
        else {
            throw RuntimeError(key: ClientErrorKeys.notARepeatingEvent.rawValue, "not a repeating event")
        }
        let enumerator = EventRepeatTimeEnumerator(
            repeating.repeatOption, endOption: repeating.repeatingEndOption)
        guard let nextEventTime = enumerator?.nextEventTime(
            from: .init(time: time, turn: 0),
            until: repeating.repeatingEndOption?.endTime
        )
        else {
            throw RuntimeError(key: ClientErrorKeys.repeatingIsEnd.rawValue, "repeaitng end")
        }
        
        let nextTodo = origin |> \.time .~ nextEventTime.time
        try await self.localStorage.updateTodoEvent(nextTodo)
        return nextTodo
    }
}


// MARK: - remove

extension TodoLocalRepositoryImple {
    
    public func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult {
        let origin = try await self.localStorage.loadTodoEvent(eventId)
        
        try await self.localStorage.removeTodo(eventId)
        
        let next: TodoEvent? = onlyThisTime
            ? try? await self.replaceTodoNextEventTimeIfIsRepeating(origin)
            : nil
        
        if next == nil {
            try? await self.localStorage.removeTodoDetail(eventId)
        }
        return RemoveTodoResult() |> \.nextRepeatingTodo .~ next
    }
}

// MARK: - skip

extension TodoLocalRepositoryImple {
    
    public func skipRepeatingTodo(_ todoId: String) async throws -> TodoEvent {
        let origin = try await self.localStorage.loadTodoEvent(todoId)
        return try await self.replaceTodoNextEventTimeIfIsRepeating(origin)
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
    
    public func loadUncompletedTodos() -> AnyPublisher<[TodoEvent], any Error> {
        return Publishers.create { [weak self] in
            let now = Date()
            return try await self?.localStorage.loadUncompletedTodos(now)
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
            try await self.localStorage.removeAllDoneEvents()
            try? await self.localStorage.removeAllDoneTodoDetail()
            
        case .pastThan(let time):
            let ids = try await localStorage.removeDoneTodos(pastThan: time)
            guard !ids.isEmpty else { return }
            try? await self.localStorage.removeDoneTodoDetails(ids)
        }
    }
    
    public func revertDoneTodo(_ doneTodoId: String) async throws -> RevertTodoResult {
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
        let detail = try? await self.localStorage.copyDoneTodoDetail(doneTodoId, to: revertTodo.uuid)
        try? await self.localStorage.removeDoneTodoDetails([doneTodoId])
        
        return .init(revertTodo: revertTodo, detail: detail)
    }
    
    public func toggleTodo(
        _ todoId: String
    ) async throws -> TodoToggleResult? {
        
        func runActionWithUpdateState<R>(
            startWith state: TodoToggleStateUpdateParamas,
            _ action: () async throws -> R
        ) async throws -> R {
            do {
                try await self.localStorage.updateTodoToggleState(todoId, state)
                let result = try await action()
                try await self.localStorage.updateTodoToggleState(todoId, .idle)
                return result
            } catch {
                try await self.localStorage.updateTodoToggleState(todoId, .idle)
                throw error
            }
        }
        
        let previousToggleState = try await self.localStorage.todoToggleState(todoId)
        
        switch previousToggleState {
        case .idle(let target):
            let result = try await runActionWithUpdateState(startWith: .completing(origin: target)) {
                return try await self.completeTodo(todoId)
            }
            return .completed(result.doneEvent)
            
        case .completing, .reverting:
            return nil
        }
    }
}
