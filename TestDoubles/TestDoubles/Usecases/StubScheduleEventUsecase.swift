//
//  StubScheduleEventUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/01.
//

import Foundation
import Combine
import Domain
import Extensions


open class StubScheduleEventUsecase: ScheduleEventUsecase {
    
    public init() { }
    
    open func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        throw RuntimeError("not implemented")
    }
    
    open func updateScheduleEvent(_ eventId: String, _ params: ScheduleEditParams) async throws -> ScheduleEvent {
        throw RuntimeError("not implemented")
    }
    
    open func refreshScheduleEvents(in period: Range<TimeInterval>) {
    
    }
    
    public var stubScheduleEventsInRange: [ScheduleEvent] = []
    open func scheduleEvents(in period: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], Never> {
        return Just(self.stubScheduleEventsInRange).eraseToAnyPublisher()
    }
}
