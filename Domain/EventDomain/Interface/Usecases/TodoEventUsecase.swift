//
//  TodoEventUsecase.swift
//  EventDomainInterface
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
    func doneTodoEvent(_ id: String) -> AnyPublisher<DoneTodoEvent, any Error>
    func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws
    
    func refreshUncompletedTodos()
    var uncompletedTodos: AnyPublisher<[TodoEvent], Never> { get }
    
    func skipRepeatingTodo(_ todoId: String) async throws -> TodoEvent
}
