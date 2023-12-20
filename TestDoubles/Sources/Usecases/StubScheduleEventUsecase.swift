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
    
    public var didMakeScheduleParams: ScheduleMakeParams?
    open func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        self.didMakeScheduleParams = params
        guard let newEvent = ScheduleEvent(params)
        else {
            throw RuntimeError("invalid parameters")
        }
        return newEvent
    }
    
    public var shouldUpdateEventFail: Bool = false
    public var didUpdateEditParams: ScheduleEditParams?
    open func updateScheduleEvent(_ eventId: String, _ params: ScheduleEditParams) async throws -> ScheduleEvent {
        self.didUpdateEditParams = params
        guard self.shouldUpdateEventFail == false
        else {
            throw RuntimeError("failed")
        }
        return .init(uuid: "some", name: "name", time: .at(0))
    }
    
    open func refreshScheduleEvents(in period: Range<TimeInterval>) {
    
    }
    
    public var stubScheduleEventsInRange: [ScheduleEvent] = []
    open func scheduleEvents(in period: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], Never> {
        return Just(self.stubScheduleEventsInRange).eraseToAnyPublisher()
    }
    
    open func removeScheduleEvent(_ eventId: String, onlyThisTime: EventTime?) async throws {
        
    }
    
    public var stubEvent: ScheduleEvent?
    open func scheduleEvent(_ eventId: String) -> AnyPublisher<ScheduleEvent, any Error> {
        guard let event = self.stubEvent
        else {
            return Empty().eraseToAnyPublisher()
        }
        return Just(event).mapNever().eraseToAnyPublisher()
    }
}
