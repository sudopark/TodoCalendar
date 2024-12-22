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
    func revertCompleteTodo(_ doneId: String) async throws -> TodoEvent
    func removeTodo(_ id: String, onlyThisTime: Bool) async throws
    func handleRemovedTodos(_ ids: [String])
    
    func refreshCurentTodoEvents()
    var currentTodoEvents: AnyPublisher<[TodoEvent], Never> { get }
    func refreshTodoEvents(in period: Range<TimeInterval>)
    func todoEvents(in period: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], Never>
    func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error>
    func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws
    
    func refreshUncompletedTodos()
    var uncompletedTodos: AnyPublisher<[TodoEvent], Never> { get }
    
    func skipRepeatingTodo(_ todoId: String, _ params: SkipTodoParams) async throws -> TodoEvent
}


// MARK: - TodoEventUsecaseImple

public final class TodoEventUsecaseImple: TodoEventUsecase {
    
    private let todoRepository: any TodoEventRepository
    private let sharedDataStore: SharedDataStore
    
    public init(
        todoRepository: any TodoEventRepository,
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
        self.updateUncompletedTodoList(by: newEvent)
        return newEvent
    }
    
    public func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        guard params.isValidForUpdate
        else {
            throw RuntimeError("invalid parameter for update Todo event")
        }
        
        if case .onlyThisTime = params.repeatingUpdateScope {
            return try await self.replaceCurrentTodoAndMakeNewEvent(eventId, params)
        } else {
            return try await self.updateSelectedTodoEvent(eventId, params)
        }
    }
    
    private func updateSelectedTodoEvent(
        _ eventId: String,
        _ params: TodoEditParams
    ) async throws -> TodoEvent {
        let updatedEvent = try await self.todoRepository.updateTodoEvent(eventId, params)
        self.notifyUpdatedEvent(updatedEvent)
        self.updateUncompletedTodoList(by: updatedEvent)
        return updatedEvent
    }
    
    private func notifyUpdatedEvent(_ event: TodoEvent) {
        let shareKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
            ($0 ?? [:]) |> key(event.uuid) .~ event
        }
    }
    
    private func replaceCurrentTodoAndMakeNewEvent(
        _ eventId: String,
        _ params: TodoEditParams
    ) async throws -> TodoEvent {
        
        let replaceResult = try await self.todoRepository.replaceRepeatingTodo(
            current: eventId, to: params.asMakeParams()
        )
        let shareKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
            ($0 ?? [:])
            |> key(eventId) .~ replaceResult.nextRepeatingTodoEvent
            |> key(replaceResult.newTodoEvent.uuid) .~ replaceResult.newTodoEvent
        }
        self.updateUncompletedTodoList(by: replaceResult.newTodoEvent)
        return replaceResult.newTodoEvent
    }
    
    public func completeTodo(_ eventId: String) async throws -> DoneTodoEvent {
        let doneResult = try await self.todoRepository.completeTodo(eventId)
        let (doneEvent, nextTodo) = (doneResult.doneEvent, doneResult.nextRepeatingTodoEvent)
        
        let todoKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: todoKey) {
            ($0 ?? [:]) |> key(doneEvent.originEventId) .~ nil
        }
        if let next = nextTodo {
            self.sharedDataStore.update([String: TodoEvent].self, key: todoKey) {
                ($0 ?? [:]) |> key(next.uuid) .~ next
            }
            self.updateUncompletedTodoList(by: next)
        }
        self.removeUncompletedTodoAtList(eventId)
        return doneEvent
    }
    
    public func revertCompleteTodo(_ doneId: String) async throws -> TodoEvent {
        let reverted = try await self.todoRepository.revertDoneTodo(doneId)
        let todoKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: todoKey) {
            ($0 ?? [:]) |> key(reverted.uuid) .~ reverted
        }
        return reverted
    }
    
    public func removeTodo(_ id: String, onlyThisTime: Bool) async throws {
        let removeResult = try await self.todoRepository.removeTodo(
            id, onlyThisTime: onlyThisTime
        )
        // onlyThisTime
            // remove current and
        let shareKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
            ($0 ?? [:])
            |> key(id) .~ removeResult.nextRepeatingTodo
        }
        self.removeUncompletedTodoAtList(id)
    }
    
    public func handleRemovedTodos(_ ids: [String]) {
        let idSet = Set(ids)
        let todoKey = ShareDataKeys.todos.rawValue
        self.sharedDataStore.update([String: TodoEvent].self, key: todoKey) {
            return ($0 ?? [:]).filter { !idSet.contains($0.key) }
        }
        let uncompletedKey = ShareDataKeys.uncompletedTodos.rawValue
        self.sharedDataStore.update([TodoEvent].self, key: uncompletedKey) { todos in
            return (todos ?? []).filter { !idSet.contains($0.uuid) }
        }
    }
    
    public func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws {
        try await self.todoRepository.removeDoneTodos(scope)
    }
}


// MARK: - load case

extension TodoEventUsecaseImple {

    public func refreshCurentTodoEvents() {
        
        let shareKey = ShareDataKeys.todos.rawValue
        let updateCached: ([TodoEvent]) -> Void = { [weak self] currents in
            self?.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
                let todosWithoutOldCurrentTodo = ($0 ?? [:]).filter { $0.value.time != nil }
                return currents.reduce(into: todosWithoutOldCurrentTodo)
                    { $0[$1.uuid] = $1 }
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
    
    public func refreshTodoEvents(in period: Range<TimeInterval>) {
        let shareKey = ShareDataKeys.todos.rawValue
        let updateCache: ([TodoEvent]) -> Void = { [weak self] todos in
            self?.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
                let cachedInRange = ($0 ?? [:]).filter { $0.value.time?.isRoughlyOverlap(with: period) ?? false }
                let refreshed = todos.asDictionary { $0.uuid }
                let removed = cachedInRange.filter { refreshed[$0.key] == nil }
                let todosWithoutRemoved = ($0 ?? [:]).filter { removed[$0.key] == nil }
                return todos.reduce(into: todosWithoutRemoved) { $0[$1.uuid] = $1 }
            }
        }
        self.todoRepository.loadTodoEvents(in: period)
            .sink(receiveCompletion: { _ in }, receiveValue: updateCache)
            .store(in: &self.cancellables)
    }
    
    public func todoEvents(in period: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], Never> {
        let shareKey = ShareDataKeys.todos.rawValue
        
        let filterInRange: ([TodoEvent]) -> [TodoEvent] = { todos in
            return todos.filter { event in
                guard let time = event.time else { return false }
                return time.isRoughlyOverlap(with: period)
            }
        }
        
        return self.sharedDataStore
            .observe([String: TodoEvent].self, key: shareKey)
            .map { $0?.values.map { $0 } ?? [] }
            .map(filterInRange)
            .eraseToAnyPublisher()
    }
    
    public func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error> {
        let updateStore: (TodoEvent) -> Void = { [weak self] event in
            let shareKey = ShareDataKeys.todos.rawValue
            self?.sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
                ($0 ?? [:]) |> key(event.uuid) .~ event
            }
        }
        return self.todoRepository.todoEvent(id)
            .handleEvents(receiveOutput: updateStore)
            .eraseToAnyPublisher()
    }
}

// MARK: - uncompleted todo

extension TodoEventUsecaseImple {
    
    public func refreshUncompletedTodos() {
        
        let shareKey = ShareDataKeys.uncompletedTodos.rawValue
        let refreshCached: ([TodoEvent]) -> Void = { [weak self] todos in
            self?.sharedDataStore.put([TodoEvent].self, key: shareKey, todos)
        }
        self.todoRepository.loadUncompletedTodos()
            .sink(receiveValue: refreshCached)
            .store(in: &self.cancellables)
    }
    
    public var uncompletedTodos: AnyPublisher<[TodoEvent], Never> {
        let shareKey = ShareDataKeys.uncompletedTodos.rawValue
        return self.sharedDataStore.observe([TodoEvent].self, key: shareKey)
            .map { $0 ?? [] }
            .eraseToAnyPublisher()
    }
    
    private func updateUncompletedTodoList(by updatedTodo: TodoEvent) {
        let time = updatedTodo.time; let now = Date().timeIntervalSince1970
        switch time {
        case .none:
            self.removeUncompletedTodoAtList(updatedTodo.uuid)
            
        case .some(let t) where t.upperBoundWithFixed <= now:
            self.updateOrAppendUncompletedTodoAtList(updatedTodo)
            
        case .some:
            self.removeUncompletedTodoAtList(updatedTodo.uuid)
        }
    }
    
    private func updateOrAppendUncompletedTodoAtList(_ todo: TodoEvent) {
        let shareKey = ShareDataKeys.uncompletedTodos.rawValue
        self.sharedDataStore.update([TodoEvent].self, key: shareKey) { todos in
            let todos = todos ?? []
            if let index = todos.firstIndex(where: { $0.eventId == todo.uuid }) {
                return todos |> ix(index) .~ todo
            } else {
                return todos + [todo]
            }
        }
    }
    
    private func removeUncompletedTodoAtList(_ todoId: String) {
        let shareKey = ShareDataKeys.uncompletedTodos.rawValue
        self.sharedDataStore.update([TodoEvent].self, key: shareKey) {
            return ($0 ?? []).filter { $0.uuid != todoId }
        }
    }
}


// MARK: - skip todo

extension TodoEventUsecaseImple {
    
    public func skipRepeatingTodo(
        _ todoId: String, _ params: SkipTodoParams
    ) async throws -> TodoEvent {
        
        switch params {
        case .next:
            let skipped = try await self.todoRepository.skipRepeatingTodo(todoId)
            self.notifyUpdatedEvent(skipped)
            self.updateUncompletedTodoList(by: skipped)
            return skipped
            
        case .until(let next):
            let params = TodoEditParams(.patch) |> \.time .~ next
            let skipped = try await self.updateTodoEvent(todoId, params)
            self.updateUncompletedTodoList(by: skipped)
            return skipped
        }
    }
}
