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
    
    func refreshCurentTodoEvents()
    var currentTodoEvents: AnyPublisher<[TodoEvent], Never> { get }
    func refreshTodoEvents(in period: Range<TimeStamp>)
    func todoEvents(in period: Range<TimeStamp>) -> AnyPublisher<[TodoEvent], Never>
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
    
    private var cancellables: Set<AnyCancellable> = []
}


// MARK: - make and edit case

extension TodoEventUsecaseImple {
    
    public func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        guard params.isValidForMaking
        else {
            throw RuntimeError("invalid parameter for make Todo Event")
        }
        let newEvent = try await self.todoRepository.makeTodoEvent(params)
        
        let shareKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
            ($0 ?? [:]) |> key(newEvent.uuid) .~ newEvent
        }
        return newEvent
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        guard params.isValidForUpdate
        else {
            throw RuntimeError("invalid parameter for update Todo event")
        }
        // TODO: 반복일정일 경우 유저 선택에 따른 구현 필요
        let updatedEvent = try await self.todoRepository.updateTodoEvent(eventId, params)
        
        let shareKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
            ($0 ?? [:]) |> key(eventId) .~ updatedEvent
        }
        return updatedEvent
    }
    
    public func completeTodo(_ eventId: String) async throws -> DoneTodoEvent {
        let doneResult = try await self.todoRepository.completeTodo(eventId)
        let (doneEvent, nextTodo) = (doneResult.doneEvent, doneResult.nextRepeatingTodoEvent)
        
        let (todoKey, doneKey) = (ShareDataKeys.todos.rawValue, ShareDataKeys.doneTodos.rawValue)
        self.sharedDataStore.update([String: DoneTodoEvent].self, key: doneKey) {
            ($0 ?? [:]) |> key(doneEvent.originEventId) .~ doneEvent
        }
        self.sharedDataStore.update([String: TodoEvent].self, key: todoKey) {
            ($0 ?? [:]) |> key(doneEvent.originEventId) .~ nil
        }
        if let next = nextTodo {
            self.sharedDataStore.update([String: TodoEvent].self, key: todoKey) {
                ($0 ?? [:]) |> key(next.uuid) .~ next
            }
        }
        return doneEvent
    }
}


// MARK: - load case

extension TodoEventUsecaseImple {

    public func refreshCurentTodoEvents() {
        
        let shareKey = ShareDataKeys.todos.rawValue
        let updateCached: ([TodoEvent]) -> Void = { [weak self] todos in
            self?.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
                return todos.reduce(into: $0 ?? [:]) { $0[$1.uuid] = $1 }
            }
        }
        
        self.todoRepository.loadCurrentTodoEvents()
            .sink(receiveCompletion: { _ in }, receiveValue: updateCached)
            .store(in: &self.cancellables)
    }
    
    public var currentTodoEvents: AnyPublisher<[TodoEvent], Never> {
        
        let shareKey = ShareDataKeys.todos.rawValue
        return self.sharedDataStore
            .observe([String: TodoEvent].self, key: shareKey)
            .map { $0?.values.map { $0 } ?? [] }
            .map { $0.filter { $0.time == nil } }
            .eraseToAnyPublisher()
    }
    
    public func refreshTodoEvents(in period: Range<TimeStamp>) {
        let shareKey = ShareDataKeys.todos.rawValue
        let updateCache: ([TodoEvent]) -> Void = { [weak self] todos in
            self?.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
                return todos.reduce(into: $0 ?? [:]) { $0[$1.uuid] = $1 }
            }
        }
        self.todoRepository.loadTodoEvents(in: period)
            .sink(receiveCompletion: { _ in }, receiveValue: updateCache)
            .store(in: &self.cancellables)
    }
    
    public func todoEvents(in period: Range<TimeStamp>) -> AnyPublisher<[TodoEvent], Never> {
        let shareKey = ShareDataKeys.todos.rawValue
        
        let filterInRange: ([TodoEvent]) -> [TodoEvent] = { todos in
            return todos.filter { event in
                guard let time = event.time else { return false }
                return time.isClamped(with: period)
            }
        }
        
        return self.sharedDataStore
            .observe([String: TodoEvent].self, key: shareKey)
            .map { $0?.values.map { $0 } ?? [] }
            .map(filterInRange)
            .eraseToAnyPublisher()
    }
}