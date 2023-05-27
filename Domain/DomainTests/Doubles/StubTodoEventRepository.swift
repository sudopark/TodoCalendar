//
//  StubTodoEventRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Domain
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit


class StubTodoEventRepository: TodoEventRepository, BaseStub {
    
    var shouldFailMake: Bool = false
    func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        try self.checkShouldFail(self.shouldFailMake)
        return TodoEvent(uuid: "new", name: params.name ?? "")
            |> \.eventTagId .~ params.eventTagId
            |> \.time .~ params.time
            |> \.repeating .~ params.repeating
    }
    
    var shouldFailUpdate: Bool = false
    func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        try self.checkShouldFail(self.shouldFailUpdate)
        return TodoEvent(uuid: eventId, name: params.name ?? "")
            |> \.eventTagId .~ params.eventTagId
            |> \.time .~ params.time
            |> \.repeating .~ params.repeating
    }
    
    var shouldFailComplete: Bool = false
    var doneEventIsRepeating: Bool = false
    func completeTodo(_ eventId: String) async throws -> CompleteTodoResult {
        try self.checkShouldFail(self.shouldFailComplete)
        let doneEvent = DoneTodoEvent(uuid: "done", name: "some", originEventId: eventId, doneTime: .now)
        var nextTodo: TodoEvent?
        if self.doneEventIsRepeating {
            nextTodo = TodoEvent(uuid: "next", name: "next todo")
        }
        return .init(doneEvent: doneEvent, nextRepeatingTodoEvent: nextTodo)
    }
    
    var shouldFailReplaceRepeatingTodo: Bool = false
    var isAvailToSkipNextTodo: Bool = true
    func replaceRepeatingTodo(
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
                        |> \.time .~ .at(.dummy(100))
                )
        }
        return .init(newTodoEvent: newTodo)
    }
    
    var shouldFailLoadCurrentTodoEvents: Bool = false
    func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], Error> {
        guard self.shouldFailLoadCurrentTodoEvents == false else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        let events = (10..<30).map { TodoEvent.dummy($0) }
        return Just(events).mapNever().eraseToAnyPublisher()
    }
    
    var shouldFailLoadTodosInRange: Bool = false
    func loadTodoEvents(in range: Range<TimeStamp>) -> AnyPublisher<[TodoEvent], Error> {
        guard self.shouldFailLoadTodosInRange == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        let events = (-10..<0).map {
            TodoEvent.dummy($0) |> \.time .~ .at(.dummy($0))
        }
        return Just(events).mapNever().eraseToAnyPublisher()
    }
}
