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
            |> \.exceptFromRepeatedEventId .~ params.exceptFromRepeatedScheduleId
    }
    
    var shouldFailUpdate: Bool = false
    func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        try self.checkShouldFail(self.shouldFailUpdate)
        return TodoEvent(uuid: eventId, name: params.name ?? "")
            |> \.eventTagId .~ params.eventTagId
            |> \.time .~ params.time
            |> \.repeating .~ params.repeating
            |> \.exceptFromRepeatedEventId .~ params.exceptFromRepeatedScheduleId
    }
    
    var shouldFailComplete: Bool = false
    var doneEventIsRepeating: Bool = false
    func completeTodo(_ eventId: String) async throws -> DoneTodoEvent {
        try self.checkShouldFail(self.shouldFailComplete)
        let event = DoneTodoEvent(uuid: "done", name: "some", originEventId: eventId, doneTime: .now)
            |> \.originEventIsRepeating .~ self.doneEventIsRepeating
        return event
    }
    
    var shouldFailLoadCurrentTodoEvents: Bool = false
    func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], Error> {
        guard self.shouldFailLoadCurrentTodoEvents == false else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        let events = (10..<30).map { TodoEvent.dummy($0) }
        return Just(events).mapNever().eraseToAnyPublisher()
    }
    
    var shouldFailLoadTodoEvents: Bool = false
    func loadTodoEvnets(in range: Range<Date>) -> AnyPublisher<[TodoEvent], Error> {
        guard self.shouldFailLoadTodoEvents == false else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        let events = (0..<10).map { TodoEvent.dummy($0) }
        return Just(events).mapNever().eraseToAnyPublisher()
    }
    
    var shouldFailLoadDoneEvents: Bool = false
    func loadDoneEvents(in range: Range<Date>) -> AnyPublisher<[DoneTodoEvent], Error> {
        guard self.shouldFailLoadDoneEvents == false else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        let events = (0..<10).map { DoneTodoEvent.dummy($0) }
        return Just(events).mapNever().eraseToAnyPublisher()
    }
}
