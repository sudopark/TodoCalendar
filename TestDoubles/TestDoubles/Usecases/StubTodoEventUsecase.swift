//
//  StubTodoEventUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/01.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions


open class StubTodoEventUsecase: TodoEventUsecase {
    
    private var fakeDoneTodoIdLists = CurrentValueSubject<Set<String>, Never>([])
    
    public init() {}
    
    private func todosWithoutDone(_ targets: [TodoEvent]) ->AnyPublisher<[TodoEvent], Never> {
        return self.fakeDoneTodoIdLists.map { doneIds in
            return targets.filter { !doneIds.contains($0.uuid) }
        }
        .eraseToAnyPublisher()
    }
    
    public var shouldFailMakeTodo: Bool = false
    public var didMakeTodoWithParams: TodoMakeParams?
    open func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        self.didMakeTodoWithParams = params
        guard shouldFailMakeTodo == false
        else {
            throw RuntimeError("failed")
        }

        guard let newEvent = TodoEvent(params)
        else {
            throw RuntimeError("invalid parameters")
        }
        return newEvent
    }
    
    open func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        throw RuntimeError("not implemented")
    }
    
    public var shouldFailCompleteTodo: Bool = false
    open func completeTodo(_ eventId: String) async throws -> DoneTodoEvent {
        guard shouldFailCompleteTodo == false
        else {
            throw RuntimeError("not implemented")
        }
        let newIds = self.fakeDoneTodoIdLists.value <> [eventId]
        self.fakeDoneTodoIdLists.send(newIds)
        return DoneTodoEvent(TodoEvent(uuid: eventId, name: "some"))
    }
    
    
    open func refreshCurentTodoEvents() {
        
    }
    
    public var stubCurrentTodoEvents: [TodoEvent] = []
    open var currentTodoEvents: AnyPublisher<[TodoEvent], Never> {
        return self.todosWithoutDone(self.stubCurrentTodoEvents)
    }

    open func refreshTodoEvents(in period: Range<TimeInterval>) {
        
    }

    public var stubTodoEventsInRange: [TodoEvent] = []
    open func todoEvents(in period: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], Never> {
        return self.todosWithoutDone(self.stubTodoEventsInRange)
    }
    

    open func removeTodo(_ id: String, onlyThisTime: Bool) async throws {
    }
        
    open func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error> {
        return Empty().eraseToAnyPublisher()
    }
}
