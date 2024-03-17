//
//  TodoRemoteRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 3/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions


public final class TodoRemoteRepositoryImple: TodoEventRepository, Sendable {
    
    private let remote: any RemoteAPI
    private let cacheStorage: any TodoLocalStorage
    
    public init(
        remote: any RemoteAPI,
        cacheStorage: any TodoLocalStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
    }
}

// MARK: - make

extension TodoRemoteRepositoryImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        let endpoint = TodoAPIEndpoints.make
        let payload = params.asJson()
        let mapper: TodoEventMapper = try await self.remote.request(
            .post, 
            endpoint, 
            parameters: payload
        )
        let newTodo = mapper.todo
        try? await self.cacheStorage.saveTodoEvent(newTodo)
        return newTodo
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        let endpoint = TodoAPIEndpoints.todo(eventId)
        let payload = params.asJson()
        let mapper: TodoEventMapper = try await self.remote.request(
            .patch, 
            endpoint, 
            parameters: payload
        )
        let updated = mapper.todo
        try? await self.cacheStorage.updateTodoEvent(updated)
        return updated
    }
}

// MARK: - complete

extension TodoRemoteRepositoryImple {
    
    public func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        
        let origin = try await self.loadTodoEvent(eventId)
        let nextTime = self.findNextRepeatingEvent(origin)
        
        let payload = DoneTodoEventParams(origin, nextTime)
        let endpoint = TodoAPIEndpoints.done(eventId)
        let mapper: CompleteTodoResultMapper = try await remote.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        let result = mapper.result
        
        // update cache
        try? await cacheStorage.removeTodo(eventId)
        try? await cacheStorage.saveDoneTodoEvent(result.doneEvent)
        if let next = result.nextRepeatingTodoEvent {
            try? await cacheStorage.updateTodoEvent(next)
        }
        return result
    }
    
    public func replaceRepeatingTodo(
        current eventId: String,
        to newParams: TodoMakeParams
    ) async throws -> ReplaceRepeatingTodoEventResult {
        
        let origin = try await self.loadTodoEvent(eventId)
        let nextTime = self.findNextRepeatingEvent(origin)
        
        let payload = ReplaceRepeatingTodoEventParams(newParams, nextTime)
        let endpoint = TodoAPIEndpoints.replaceRepeating(eventId)
        let mapper: ReplaceRepeatingTodoEventResultMapper = try await remote.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        let result = mapper.result
        
        // update cache
        try? await cacheStorage.removeTodo(eventId)
        try? await cacheStorage.saveTodoEvent(result.newTodoEvent)
        if let next = result.nextRepeatingTodoEvent {
            try await cacheStorage.updateTodoEvent(next)
        }
        return result
    }
    
    private func findNextRepeatingEvent(_ origin: TodoEvent) -> EventTime? {
        guard let repeating = origin.repeating,
              let time = origin.time
        else { return nil }
        
        return EventRepeatTimeEnumerator(repeating.repeatOption)?.nextEventTime(from: time, until: repeating.repeatingEndTime)
    }
}

// MARK: - remove

extension TodoRemoteRepositoryImple {
    
    public func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult {
        if onlyThisTime {
            return try await self.replaceCurrentTodoToNext(eventId)
        } else {
            return try await self.removeTodo(eventId: eventId)
        }
    }
    
    private func replaceCurrentTodoToNext(_ eventid: String) async throws -> RemoveTodoResult {
        let origin = try await self.loadTodoEvent(eventid)
        guard let nextEventTime = self.findNextRepeatingEvent(origin)
        else{
            return try await self.removeTodo(eventId: eventid)
        }
        let params = TodoEditParams() |> \.time .~ nextEventTime
        let endpoint = TodoAPIEndpoints.todo(eventid)
        let mapper: TodoEventMapper = try await self.remote.request(
            .patch,
            endpoint,
            parameters: params.asJson()
        )
        
        let updated = mapper.todo
        try? await self.cacheStorage.updateTodoEvent(updated)
        return .init()
            |> \.nextRepeatingTodo .~ updated
    }
    
    private func removeTodo(eventId: String) async throws -> RemoveTodoResult {
        let endpoint = TodoAPIEndpoints.todo(eventId)
        let _ : RemoveTodoResultMapper = try await self.remote.request(
            .delete,
            endpoint
        )
        try? await self.cacheStorage.removeTodo(eventId)
        return .init()
    }
}

// MARK: - load

extension TodoRemoteRepositoryImple {
    
    public func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    public func loadTodoEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[TodoEvent], Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    public func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    private func loadTodoEvent(_ id: String) async throws -> TodoEvent {
        let endpoint = TodoAPIEndpoints.todo(id)
        let mapper: TodoEventMapper = try await self.remote.request(
            .get,
            endpoint
        )
        return mapper.todo
    }
}
