//
//  TodoEventRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/03/20.
//

import Foundation
import Combine


public protocol TodoEventRepository: AnyObject, Sendable {
    
    func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent
    func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent
    func completeTodo(_ eventId: String) async throws -> CompleteTodoResult
    func replaceRepeatingTodo(current eventId: String, to newParams: TodoMakeParams) async throws -> ReplaceRepeatingTodoEventResult
    func removeTodo(_ eventId: String, onlyThisTime: Bool) async throws -> RemoveTodoResult
    func skipRepeatingTodo(_ todoId: String) async throws -> TodoEvent
    
    func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], any Error>
    func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], any Error>
    func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error>
    func loadUncompletedTodos() -> AnyPublisher<[TodoEvent], any Error>
    
    func loadDoneTodoEvents(_ params: DoneTodoLoadPagingParams) async throws -> [DoneTodoEvent]
    func removeDoneTodos(_ scope: RemoveDoneTodoScope) async throws
    func revertDoneTodo(_ doneTodoId: String) async throws -> RevertTodoResult
    func loadDoneTodoEvent(_ uuid: String) -> AnyPublisher<DoneTodoEvent, any Error>
    func toggleTodo(_ todoId: String) async throws -> TodoToggleResult?
}
