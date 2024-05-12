//
//  StubTodoEventRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/02.
//

import Foundation
import Domain
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit


open class StubTodoEventRepository: TodoEventRepository, BaseStub {
    
    public init() {}
    
    public var shouldFailMake: Bool = false
    open func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        try self.checkShouldFail(self.shouldFailMake)
        return TodoEvent(uuid: "new", name: params.name ?? "")
            |> \.eventTagId .~ params.eventTagId
            |> \.time .~ params.time
            |> \.repeating .~ params.repeating
    }
    
    public var shouldFailUpdate: Bool = false
    open func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        try self.checkShouldFail(self.shouldFailUpdate)
        return TodoEvent(uuid: eventId, name: params.name ?? "")
            |> \.eventTagId .~ params.eventTagId
            |> \.time .~ params.time
            |> \.repeating .~ params.repeating
    }
    
    public var shouldFailComplete: Bool = false
    public var doneEventIsRepeating: Bool = false
    open func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        try self.checkShouldFail(self.shouldFailComplete)
        let doneEvent = DoneTodoEvent(uuid: "done", name: "some", originEventId: eventId, doneTime: .now)
        var nextTodo: TodoEvent?
        if self.doneEventIsRepeating {
            nextTodo = TodoEvent(uuid: "next", name: "next todo")
        }
        return .init(doneEvent: doneEvent, nextRepeatingTodoEvent: nextTodo)
    }
    
    public var shouldFailReplaceRepeatingTodo: Bool = false
    public var isAvailToSkipNextTodo: Bool = true
    open func replaceRepeatingTodo(
        current eventId: String,
        to newParams: TodoMakeParams
    ) async throws -> ReplaceRepeatingTodoEventResult {
        try self.checkShouldFail(self.shouldFailReplaceRepeatingTodo)
        let newTodo = TodoEvent(uuid: "new", name: newParams.name ?? "")
            |> \.eventTagId .~ newParams.eventTagId
            |> \.repeating .~ newParams.repeating
            |> \.time .~ newParams.time
        if self.isAvailToSkipNextTodo {
            return .init(newTodoEvent: newTodo)
                |> \.nextRepeatingTodoEvent .~ (
                    TodoEvent(uuid: eventId, name: "skip-next")
                        |> \.time .~ .at(100)
                )
        }
        return .init(newTodoEvent: newTodo)
    }
    
    public var shouldFailLoadCurrentTodoEvents: Bool = false
    open func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], any Error> {
        guard self.shouldFailLoadCurrentTodoEvents == false else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        let events = (10..<30).map { TodoEvent.dummy($0) }
        return Just(events).mapNever().eraseToAnyPublisher()
    }
    
    public var shouldFailLoadTodosInRange: Bool = false
    open func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error> {
        guard self.shouldFailLoadTodosInRange == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        let events = (-10..<0).map {
            TodoEvent.dummy($0) |> \.time .~ .at(TimeInterval($0))
        }
        return Just(events).mapNever().eraseToAnyPublisher()
    }
    
    public var stubRemoveTodoNextRepeatingExists: Bool = false
    open func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult {
        if stubRemoveTodoNextRepeatingExists {
            return RemoveTodoResult() |> \.nextRepeatingTodo .~ .init(uuid: eventId, name: "next")
        } else {
            return RemoveTodoResult()
        }
    }
        
    open func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    open func loadDoneTodoEvents(_ params: DoneTodoLoadPagingParams) async throws -> [DoneTodoEvent] {
        return []
    }
    
    open func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws {
        
    }
    
    open func revertDoneTodo(_ doneTodoId: String) async throws -> TodoEvent {
        return .init(uuid: "reverted", name: "reverted")
    }
}
