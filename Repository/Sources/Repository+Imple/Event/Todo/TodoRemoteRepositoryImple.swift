//
//  TodoRemoteRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 3/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import Prelude
import Optics
import Domain
import Extensions


public final class TodoRemoteRepositoryImple: TodoEventRepository, @unchecked Sendable {
    
    private let remote: any RemoteAPI
    private let cacheStorage: any TodoLocalStorage
    private var cancellables: Set<AnyCancellable> = []
    
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
            .put,
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
    
    private typealias CacheAndRefreshed = ([TodoEvent]?, [TodoEvent]?)
    
    public func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], Error> {
        
        return self.loadTodosWithReplaceCached { [weak self] in
            return try await self?.cacheStorage.loadCurrentTodoEvents()
        } thenFromRemote: { [weak self] in
            let mappers: [TodoEventMapper]? = try await self?.remote.request(
                .get, 
                TodoAPIEndpoints.currentTodo
            )
            return mappers?.map { $0.todo }
        }
    }
    
    public func loadTodoEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[TodoEvent], Error> {
        
        return self.loadTodosWithReplaceCached { [weak self] in
            return try await self?.cacheStorage.loadTodoEvents(in: range)
        } thenFromRemote: { [weak self] in
            let payload: [String: Any] = ["lower": range.lowerBound, "upper": range.upperBound]
            let mappers: [TodoEventMapper]? = try await self?.remote.request(
                .get, 
                TodoAPIEndpoints.todos,
                parameters: payload
            )
            return mappers?.map { $0.todo }
        }
    }
    
    
    public func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, Error> {
        return self.loadTodosWithReplaceCached { [weak self] in
            let cache = try await self?.cacheStorage.loadTodoEvent(id)
            return cache.map { [$0] }
        } thenFromRemote: { [weak self] in
            let refreshed = try await self?.loadTodoEvent(id)
            return refreshed.map { [$0] }
        }
        .compactMap { $0.first }
        .eraseToAnyPublisher()
    }
    
    public func loadUncompletedTodos() -> AnyPublisher<[TodoEvent], any Error> {
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
    
    private func loadTodosWithReplaceCached(
        startWithCached cacheOperation: @Sendable @escaping () async throws -> [TodoEvent]?,
        thenFromRemote remoteOperation: @Sendable @escaping () async throws -> [TodoEvent]?
    ) -> AnyPublisher<[TodoEvent], any Error> {
        
        return AnyPublisher<[TodoEvent]?, any Error>.create { subscriber in
            let task = Task { [weak self] in
                let cached = try? await cacheOperation()
                if let cached {
                    subscriber.send(cached)
                }
                do {
                    let refreshed = try await remoteOperation()
                    await self?.replaceCached(cached, refreshed)
                    subscriber.send(refreshed)
                    subscriber.send(completion: .finished)
                } catch {
                    subscriber.send(completion: .failure(error))
                }
            }
            return AnyCancellable { task.cancel() }
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
    
    private func replaceCached(
        _ cached: [TodoEvent]?,
        _ refreshed: [TodoEvent]?
    ) async {
        if let cached {
            try? await self.cacheStorage.removeTodos(cached.map { $0.uuid })
        }
        if let refreshed {
            try? await self.cacheStorage.updateTodoEvents(refreshed)
        }
    }
}


extension TodoRemoteRepositoryImple {
    
    public func loadDoneTodoEvents(
        _ params: DoneTodoLoadPagingParams
    ) async throws -> [DoneTodoEvent] {
        let mappers: [DoneTodoEventMapper] = try await self.remote.request(
            .get,
            TodoAPIEndpoints.dones,
            parameters: params.asJson()
        )
        let events = mappers.map { $0.event }
        try await self.cacheStorage.updateDoneTodos(events)
        return events
    }
    
    public func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws {
        typealias RemoveDoneTodoResultMapper = RemoveTodoResultMapper
        let _: RemoveDoneTodoResultMapper = try await remote.request(
            .delete,
            TodoAPIEndpoints.dones,
            parameters: scope.asJson()
        )
        switch scope {
        case .all: try await self.cacheStorage.removeAllDoneEvents()
        case .pastThan(let time): try await self.cacheStorage.removeDoneTodos(pastThan: time)
        }
    }
    
    public func revertDoneTodo(_ doneTodoId: String) async throws -> TodoEvent {
        let mapper: TodoEventMapper = try await self.remote.request(
            .post,
            TodoAPIEndpoints.revertDone(doneTodoId)
        )
        try await self.cacheStorage.removeDoneTodo([doneTodoId])
        try await self.cacheStorage.updateTodoEvent(mapper.todo)
        return mapper.todo
    }
    
    public func toggleTodo(_ todoId: String) async throws -> TodoToggleResult? {
        
        func runActionWithUpdateState<R>(
            startWith state: TodoToggleStateUpdateParamas,
            _ action: () async throws -> R
        ) async throws -> R {
            do {
                try await self.cacheStorage.updateTodoToggleState(todoId, state)
                let result = try await action()
                try await self.cacheStorage.updateTodoToggleState(todoId, .idle)
                return result
            } catch {
                try await self.cacheStorage.updateTodoToggleState(todoId, .idle)
                throw error
            }
        }
        
        let previousToggleState = try await self.cacheStorage.todoToggleState(todoId)
        
        switch previousToggleState {
        case .idle(let target):
            let result = try await runActionWithUpdateState(startWith: .completing(origin: target)) {
                return try await self.completeTodo(todoId)
            }
            return .completed(result.doneEvent)
            
        case .completing(let origin, let doneId):
            let result = try await runActionWithUpdateState(startWith: .reverting) {
                return try await cancelDoneTodo(origin, doneId)
            }
            return .reverted(result.reverted)
            
        case .reverting:
            return nil
        }
    }
    
    private func cancelDoneTodo(
        _ origin: TodoEvent,
        _ doneTodoId: String?
    ) async throws -> RevertToggleTodoDoneResult {
        let endpoint: TodoAPIEndpoints = .cancelDone
        let result: RevertToggleTodoDoneResult = try await self.remote.request(
            .post,
            endpoint,
            parameters: RevertToggleTodoDoneParameter(origin, doneTodoId).asJson()
        )
        try await self.cacheStorage.updateTodoEvent(result.reverted)
        if let deletedDoneId = result.deletedDoneTodoId {
            try await self.cacheStorage.removeDoneTodo([deletedDoneId])
        }
        return result
    }
}
