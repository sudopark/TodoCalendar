//
//  TodoEventUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/03/20.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - TodoEventUsecase

public protocol TodoEventUsecase {
    
    func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent
    func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent
    func completeTodo(_ eventId: String) async throws -> DoneTodoEvent
    
    func currentTodoEvents() -> AnyPublisher<[TodoEvent], Never>
    func todoEvents(in range: Range<Date>) -> AnyPublisher<TodoEventsDuringThePeriod, Never>
}


// MARK: - TodoEventUsecaseImple

public final class TodoEventUsecaseImple: TodoEventUsecase {
    
    private let todoRepository: TodoEventRepository
    private let sharedDataStore: SharedDataStore
    
    public init(
        todoRepository: TodoEventRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.todoRepository = todoRepository
        self.sharedDataStore = sharedDataStore
    }
}


// MARK: - make and edit case

extension TodoEventUsecaseImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        guard params.isValidForMaking
        else {
            throw RuntimeError("invalid parameter for make Todo Event")
        }
        let newEvent = try await self.todoRepository.makeTodoEvent(params)
        defer {
            let shareKey = ShareDataKeys.todos.rawValue
            self.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
                ($0 ?? [:]) |> key(newEvent.uuid) .~ newEvent
            }
        }
        return newEvent
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        guard params.isValidForUpdate
        else {
            throw RuntimeError("invalid parameter for update Todo event")
        }
        let updatedEvent = try await self.todoRepository.updateTodoEvent(eventId, params)
        defer {
            let shareKey = ShareDataKeys.todos.rawValue
            self.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
                ($0 ?? [:]) |> key(eventId) .~ updatedEvent
            }
        }
        return updatedEvent
    }
    
    public func completeTodo(_ eventId: String) async throws -> DoneTodoEvent {
        throw RuntimeError("not implemented")
    }
}


// MARK: - load case

extension TodoEventUsecaseImple {
    
    public func currentTodoEvents() -> AnyPublisher<[TodoEvent], Never> {
        return Empty().eraseToAnyPublisher()
    }
    
    public func todoEvents(in range: Range<Date>) -> AnyPublisher<TodoEventsDuringThePeriod, Never> {
        return Empty().eraseToAnyPublisher()
    }
}
