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
            .post, endpoint, parameters: payload
        )
        let newTodo = mapper.todo
        try? await self.cacheStorage.saveTodoEvent(newTodo)
        return newTodo
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        let endpoint = TodoAPIEndpoints.todo(eventId)
        let payload = params.asJson()
        let mapper: TodoEventMapper = try await self.remote.request(
            .patch, endpoint, parameters: payload
        )
        let updated = mapper.todo
        try? await self.cacheStorage.updateTodoEvent(updated)
        return updated
    }
}

// MARK: - complete

extension TodoRemoteRepositoryImple {
    
    public func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        throw RuntimeError("not implemented")
    }
    
    public func replaceRepeatingTodo(
        current eventId: String,
        to newParams: TodoMakeParams
    ) async throws -> ReplaceRepeatingTodoEventResult {
        throw RuntimeError("not implemented")
    }
}

// MARK: - remove

extension TodoRemoteRepositoryImple {
    
    public func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult {
        throw RuntimeError("not implemented")
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
}
