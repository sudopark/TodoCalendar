//
//  TodoItemPlanRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/03/20.
//

import Foundation
import Combine


public protocol TodoItemPlanRepository {
    
    func makeTodoEvent(_ params: TodoEventMakeParams) async throws -> TodoEvent
    func updateTodoEvent(_ eventId: String, _ params: TodoEventMakeParams) async throws -> TodoEvent
    func loadTodoEvnets(in range: Range<Date>) -> AnyPublisher<[TodoEvent], Error>
}
