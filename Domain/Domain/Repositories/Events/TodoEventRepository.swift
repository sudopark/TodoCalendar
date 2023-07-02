//
//  TodoEventRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/03/20.
//

import Foundation
import Combine


public protocol TodoEventRepository {
    
    func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent
    func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent
    func completeTodo(_ eventId: String) async throws -> CompleteTodoResult
    func replaceRepeatingTodo(current eventId: String, to newParams: TodoMakeParams) async throws -> ReplaceRepeatingTodoEventResult
    
    func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], Error>
    func loadTodoEvents(in range: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], Error>
}
