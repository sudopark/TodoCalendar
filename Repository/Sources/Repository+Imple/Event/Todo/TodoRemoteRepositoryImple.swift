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
    
    private let remote: any TodoRemote
    private let cacheStorage: any TodoLocalStorage
    private var cancellables: Set<AnyCancellable> = []
    
    public init(
        remote: any TodoRemote,
        cacheStorage: any TodoLocalStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
    }
}

// MARK: - make

extension TodoRemoteRepositoryImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        let newTodo = try await self.remote.makeTodoEvent(params)
        try? await self.cacheStorage.saveTodoEvent(newTodo)
        return newTodo
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        let updated = try await self.remote.updateTodoEvent(eventId, params)
        try? await self.cacheStorage.updateTodoEvent(updated)
        return updated
    }
}

// MARK: - complete

extension TodoRemoteRepositoryImple {
    
    public func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        
        let origin = try await self.remote.loadTodo(eventId)
        let nextTime = try? self.findNextRepeatingEvent(origin)
        
        let result = try await self.remote.completeTodo(origin: origin, nextTime: nextTime)
        
        // update cache
        try? await cacheStorage.removeTodo(eventId)
        
        try? await cacheStorage.saveDoneTodoEvent(result.doneEvent)
        if let doneDetail = result.doneTodoEventDetail {
            try? await cacheStorage.saveDoneTodoDetail(doneDetail)
        }
        if let next = result.nextRepeatingTodoEvent {
            try? await cacheStorage.updateTodoEvent(next)
        } else {
            try? await cacheStorage.removeTodoDetail(eventId)
        }
        
        return result
    }
    
    public func replaceRepeatingTodo(
        current eventId: String,
        to newParams: TodoMakeParams
    ) async throws -> ReplaceRepeatingTodoEventResult {
        
        let origin = try await self.remote.loadTodo(eventId)
        let nextTime = try? self.findNextRepeatingEvent(origin)
        
        let result = try await self.remote.replaceRepeatingTodo(
            origin: origin, to: newParams, nextTime: nextTime
        )
        
        // update cache
        try? await cacheStorage.removeTodo(eventId)
        try? await cacheStorage.saveTodoEvent(result.newTodoEvent)
        if let next = result.nextRepeatingTodoEvent {
            try await cacheStorage.updateTodoEvent(next)
        } else {
            try? await cacheStorage.removeTodoDetail(eventId)
        }
        return result
    }
    
    private func findNextRepeatingEvent(_ origin: TodoEvent) throws -> EventTime {
        guard let repeating = origin.repeating,
              let time = origin.time
        else {
            throw RuntimeError(key: ClientErrorKeys.notARepeatingEvent.rawValue, "not a repeating event")
        }
        
        let enumerator = EventRepeatTimeEnumerator(
            repeating.repeatOption, endOption: repeating.repeatingEndOption
        )
        guard let next =  enumerator?.nextEventTime(
            from: .init(time: time, turn: 0),
            until: repeating.repeatingEndOption?.endTime
        )
        else {
            throw RuntimeError(key: ClientErrorKeys.repeatingIsEnd.rawValue, "repeaitng end")
        }
        return next.time
    }
}

// MARK: - remove

extension TodoRemoteRepositoryImple {
    
    public func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult {
        let result = if onlyThisTime {
            try await self.replaceCurrentTodoToNext(eventId)
        } else {
            try await self.removeTodo(eventId: eventId)
        }
        
        if result.nextRepeatingTodo == nil {
            try? await self.cacheStorage.removeTodoDetail(eventId)
        }
        
        return result
    }
    
    private func replaceCurrentTodoToNext(_ eventid: String) async throws -> RemoveTodoResult {
        let origin = try await self.remote.loadTodo(eventid)
        guard let nextEventTime = try? self.findNextRepeatingEvent(origin)
        else{
            return try await self.removeTodo(eventId: eventid)
        }
        let params = TodoEditParams(.patch) |> \.time .~ nextEventTime
        let updated = try await self.updateTodoEvent(eventid, params)
        return .init()
            |> \.nextRepeatingTodo .~ updated
    }
    
    private func removeTodo(eventId: String) async throws -> RemoveTodoResult {
        let result = try await self.remote.removeTodo(eventId: eventId)
        try? await self.cacheStorage.removeTodo(eventId)
        return result
    }
}

// MARK: - skip

extension TodoRemoteRepositoryImple {
    
    public func skipRepeatingTodo(_ todoId: String) async throws -> TodoEvent {
        let origin = try await self.remote.loadTodo(todoId)
        let next = try self.findNextRepeatingEvent(origin)
        let params = TodoEditParams(.patch) |> \.time .~ next
        return try await self.updateTodoEvent(todoId, params)
    }
}

// MARK: - load

extension TodoRemoteRepositoryImple {
    
    private typealias CacheAndRefreshed = ([TodoEvent]?, [TodoEvent]?)
    
    public func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], Error> {
        
        return self.loadTodosWithReplaceCached { [weak self] in
            return try await self?.cacheStorage.loadCurrentTodoEvents()
        } thenFromRemote: { [weak self] in
            return try await self?.remote.loadCurrentTodos()
        }
    }
    
    public func loadTodoEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[TodoEvent], Error> {
        
        return self.loadTodosWithReplaceCached { [weak self] in
            return try await self?.cacheStorage.loadTodoEvents(in: range)
        } thenFromRemote: { [weak self] in
            return try await self?.remote.loadTodos(in: range)
        }
    }
    
    
    public func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, Error> {
        return self.loadTodosWithReplaceCached { [weak self] in
            let cache = try await self?.cacheStorage.loadTodoEvent(id)
            return cache.map { [$0] }
        } thenFromRemote: { [weak self] in
            let refreshed = try await self?.remote.loadTodo(id)
            return refreshed.map { [$0] }
        }
        .compactMap { $0.first }
        .eraseToAnyPublisher()
    }
    
    public func loadUncompletedTodos() -> AnyPublisher<[TodoEvent], any Error> {
        let now = Date()
        return self.loadTodosWithReplaceCached { [weak self] in
            return try await self?.cacheStorage.loadUncompletedTodos(now)
        } thenFromRemote: { [weak self] in
            return try await self?.remote.loadUncompletedTodosFromRemote(now)
        } withRefreshCache: { [weak self] _, refreshed in
            if let refreshed {
                try? await self?.cacheStorage.updateTodoEvents(refreshed)
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func loadTodosWithReplaceCached(
        startWithCached cacheOperation: @Sendable @escaping () async throws -> [TodoEvent]?,
        thenFromRemote remoteOperation: @Sendable @escaping () async throws -> [TodoEvent]?,
        withRefreshCache replaceCacheOperation: (@Sendable ([TodoEvent]?, [TodoEvent]?) async -> Void)? = nil
    ) -> AnyPublisher<[TodoEvent], any Error> {
        
        return AnyPublisher<[TodoEvent]?, any Error>.create { subscriber in
            let task = Task { [weak self] in
                let cached = try? await cacheOperation()
                if let cached {
                    subscriber.send(cached)
                }
                do {
                    let refreshed = try await remoteOperation()
                    if let customReplaceOperation = replaceCacheOperation {
                        await customReplaceOperation(cached, refreshed)
                    } else {
                        await self?.replaceCached(cached, refreshed)
                    }
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
        let events = try await self.remote.loadDoneTodoEvents(params)
        try await self.cacheStorage.updateDoneTodos(events)
        return events
    }
    
    public func loadDoneTodoEvent(_ uuid: String) -> AnyPublisher<DoneTodoEvent, any Error> {
        
        let (cache, remote) = (self.cacheStorage, self.remote)
        
        return AnyPublisher<DoneTodoEvent, any Error>.create { subscriber in
            
            let task = Task {
                let cached = try? await cache.loadDoneTodoEvent(doneEventId: uuid)
                if let cached {
                    subscriber.send(cached)
                }
                
                do {
                    let refreshed = try await remote.loadDoneTodo(uuid)
                    
                    try? await cache.updateDoneTodos([refreshed])
                    
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
    
    public func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws {
        try await self.remote.removeDoneTodos(scope)
        switch scope {
        case .all:
            try await self.cacheStorage.removeAllDoneEvents()
            try? await self.cacheStorage.removeAllDoneTodoDetail()
            
        case .pastThan(let time):
            let ids = try await self.cacheStorage.removeDoneTodos(pastThan: time)
            guard !ids.isEmpty else { return }
            try? await self.cacheStorage.removeDoneTodoDetails(ids)
        }
    }
    
    public func revertDoneTodo(_ doneTodoId: String) async throws -> RevertTodoResult {
        let result = try await self.remote.revertDoneTodo(doneTodoId)
        try await self.cacheStorage.removeDoneTodo([doneTodoId])
        try? await self.cacheStorage.removeDoneTodoDetails([doneTodoId])
        
        try await self.cacheStorage.updateTodoEvent(result.revertTodo)
        if let detail = result.revertTodoDetail {
            try? await self.cacheStorage.saveTodoDetail(detail)
        }
        return result
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
        let result = try await self.remote.cancelDoneTodo(origin, doneTodoId)
        try await self.cacheStorage.updateTodoEvent(result.reverted)
        if let deletedDoneId = result.deletedDoneTodoId {
            try await self.cacheStorage.removeDoneTodo([deletedDoneId])
        }
        return result
    }
}
