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
    func completeTodo(_ eventId: String) async throws -> DoneTodoEvent
    
    func loadCurrentTodoEvents() -> AnyPublisher<[TodoEvent], Error>
    
    func loadTodoEvnets(in range: Range<Date>) -> AnyPublisher<[TodoEvent], Error>
    func loadDoneEvents(in range: Range<Date>) -> AnyPublisher<[DoneTodoEvent], Error>
}
