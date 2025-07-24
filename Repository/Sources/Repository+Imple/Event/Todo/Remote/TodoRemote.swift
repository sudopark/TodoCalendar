//
//  TodoRemote.swift
//  Repository
//
//  Created by sudo.park on 7/25/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - TodoRemote

public protocol TodoRemote: Sendable {
    
    func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent
    
    func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent
    
    func completeTodo(
        origin: TodoEvent,
        nextTime: EventTime?
    ) async throws -> CompleteTodoResult
    
    func replaceRepeatingTodo(
        origin: TodoEvent,
        to newParams: TodoMakeParams,
        nextTime: EventTime?
    ) async throws -> ReplaceRepeatingTodoEventResult
    
    func removeTodo(eventId: String) async throws -> RemoveTodoResult
    
    func loadCurrentTodos() async throws -> [TodoEvent]
    
    func loadTodos(in range: Range<TimeInterval>) async throws -> [TodoEvent]
    
    func loadTodo(_ id: String) async throws -> TodoEvent
    
    func loadUncompletedTodosFromRemote(_ now: Date) async throws -> [TodoEvent]
    
    func loadDoneTodoEvents(
        _ params: DoneTodoLoadPagingParams
    ) async throws -> [DoneTodoEvent]
    
    func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws
    
    func revertDoneTodo(_ doneTodoId: String) async throws -> TodoEvent
    
    func cancelDoneTodo(
        _ origin: TodoEvent,
        _ doneTodoId: String?
    ) async throws -> RevertToggleTodoDoneResult
}


// MARK: - TodoRemoteImple

public final class TodoRemoteImple: TodoRemote {
    
    private let remote: any RemoteAPI
    public init(remote: any RemoteAPI) {
        self.remote = remote
    }
}


extension TodoRemoteImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        let endpoint = TodoAPIEndpoints.make
        let payload = params.asJson()
        let mapper: TodoEventMapper = try await self.remote.request(
            .post,
            endpoint,
            parameters: payload
        )
        return mapper.todo
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        let endpoint = TodoAPIEndpoints.todo(eventId)
        let payload = params.asJson()
        let method: RemoteAPIMethod = params.editMethod == .put ? .put : .patch
        let mapper: TodoEventMapper = try await self.remote.request(
            method,
            endpoint,
            parameters: payload
        )
        return mapper.todo
    }
    
    public func completeTodo(
        origin: TodoEvent,
        nextTime: EventTime?
    ) async throws -> CompleteTodoResult {
        let payload = DoneTodoEventParams(origin, nextTime)
        let endpoint = TodoAPIEndpoints.done(origin.uuid)
        let mapper: CompleteTodoResultMapper = try await remote.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        return mapper.result
    }
    
    public func replaceRepeatingTodo(
        origin: TodoEvent,
        to newParams: TodoMakeParams,
        nextTime: EventTime?
    ) async throws -> ReplaceRepeatingTodoEventResult {
        let payload = ReplaceRepeatingTodoEventParams(newParams, nextTime)
        let endpoint = TodoAPIEndpoints.replaceRepeating(origin.uuid)
        let mapper: ReplaceRepeatingTodoEventResultMapper = try await remote.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        return mapper.result
    }
    
    public func removeTodo(eventId: String) async throws -> RemoveTodoResult {
        let endpoint = TodoAPIEndpoints.todo(eventId)
        let _ : RemoveTodoResultMapper = try await self.remote.request(
            .delete,
            endpoint
        )
        return .init()
    }
    
    public func loadCurrentTodos() async throws -> [TodoEvent] {
        let mappers: [TodoEventMapper] = try await self.remote.request(
            .get,
            TodoAPIEndpoints.currentTodo
        )
        return mappers.map { $0.todo }
    }
    
    public func loadTodos(in range: Range<TimeInterval>) async throws -> [TodoEvent] {
        let payload: [String: Any] = ["lower": range.lowerBound, "upper": range.upperBound]
        let mappers: [TodoEventMapper] = try await self.remote.request(
            .get,
            TodoAPIEndpoints.todos,
            parameters: payload
        )
        return mappers.map { $0.todo }
    }
    
    public func loadTodo(_ id: String) async throws -> TodoEvent {
        let endpoint = TodoAPIEndpoints.todo(id)
        let mapper: TodoEventMapper = try await self.remote.request(
            .get,
            endpoint
        )
        return mapper.todo
    }
    
    public func loadUncompletedTodosFromRemote(_ now: Date) async throws -> [TodoEvent] {
        let params = ["refTime": now.timeIntervalSince1970]
        let mapper: [TodoEventMapper] = try await self.remote.request(
            .get,
            TodoAPIEndpoints.uncompleteds,
            parameters: params
        )
        return mapper.map { $0.todo }
    }
    
    public func loadDoneTodoEvents(
        _ params: DoneTodoLoadPagingParams
    ) async throws -> [DoneTodoEvent] {
        let mappers: [DoneTodoEventMapper] = try await self.remote.request(
            .get,
            TodoAPIEndpoints.dones,
            parameters: params.asJson()
        )
        let events = mappers.map { $0.event }
        return events
    }
    
    public func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws {
        typealias RemoveDoneTodoResultMapper = RemoveTodoResultMapper
        let _: RemoveDoneTodoResultMapper = try await remote.request(
            .delete,
            TodoAPIEndpoints.dones,
            parameters: scope.asJson()
        )
    }
    
    public func revertDoneTodo(_ doneTodoId: String) async throws -> TodoEvent {
        let mapper: TodoEventMapper = try await self.remote.request(
            .post,
            TodoAPIEndpoints.revertDone(doneTodoId)
        )
        return mapper.todo
    }
    
    public func cancelDoneTodo(
        _ origin: TodoEvent,
        _ doneTodoId: String?
    ) async throws -> RevertToggleTodoDoneResult {
        let endpoint: TodoAPIEndpoints = .cancelDone
        let result: RevertToggleTodoDoneResult = try await self.remote.request(
            .post,
            endpoint,
            parameters: RevertToggleTodoDoneParameter(origin, doneTodoId).asJson()
        )
        return result
    }
}
