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
    
    private let localStorage: TodoLocalStorage
    private let environmentStorage: any EnvironmentStorage
    public init(
        localStorage: TodoLocalStorage,
        environmentStorage: any EnvironmentStorage
    ) {
        self.localStorage = localStorage
        self.environmentStorage = environmentStorage
    }
}


extension TodoLocalRepositoryImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        guard let newTodo = TodoEvent(params)
        else {
            throw RuntimeError("invalid parameter")
        }
        try await self.localStorage.saveTodoEvent(newTodo)
        self.updateLatestUsedEventTag(params.eventTagId)
        return newTodo
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        let origin = try await self.localStorage.loadTodoEvent(eventId)
        let updated = origin.apply(params)
        try await self.localStorage.updateTodoEvent(updated)
        self.updateLatestUsedEventTag(params.eventTagId)
        return updated
    }
    
    private func updateLatestUsedEventTag(_ tagId: String?) {
        let key = "latest_used_event_tag_id"
        if let id = tagId {
            self.environmentStorage.update(key, id)
        } else {
            self.environmentStorage.remove(key)
        }
    }
}


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
}
