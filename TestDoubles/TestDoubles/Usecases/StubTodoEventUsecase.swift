//
//  StubTodoEventUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/01.
//

import Foundation
import Combine
import Domain
import Extensions


open class StubTodoEventUsecase: TodoEventUsecase {
    
    public init() {} 
    
    open func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
        throw RuntimeError("not implemented")
    }
    
    open func updateTodoEvent(_ eventId: String, _ params: TodoEditParams) async throws -> TodoEvent {
        throw RuntimeError("not implemented")
    }
    
    open func completeTodo(_ eventId: String) async throws -> DoneTodoEvent {
        throw RuntimeError("not implemented")
    }
    
    open func refreshCurentTodoEvents() {
        
    }
    
    open var currentTodoEvents: AnyPublisher<[TodoEvent], Never> {
        return Empty().eraseToAnyPublisher()
    }

    open func refreshTodoEvents(in period: Range<TimeStamp>) {
        
    }
    
    open func todoEvents(in period: Range<TimeStamp>) -> AnyPublisher<[TodoEvent], Never> {
        return Empty().eraseToAnyPublisher()
    }
}
