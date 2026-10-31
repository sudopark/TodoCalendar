//
//  ScheduleEventUsecase.swift
//  EventDomainInterface
//
//  Created by sudo.park on 2023/05/01.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - ScheduleEventUsecase

public protocol ScheduleEventUsecase: Sendable {
    
    func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent
    func updateScheduleEvent(_ eventId: String, _ params: SchedulePutParams) async throws -> ScheduleEvent
    func removeScheduleEvent(
        _ eventId: String, onlyThisTime: EventTime?
    ) async throws
    func handleRemovedSchedules(_ ids: [String])
    
    func refreshScheduleEvents(in period: Range<TimeInterval>)
    func scheduleEvents(in period: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], Never>
    func scheduleEvent(_ eventId: String) -> AnyPublisher<ScheduleEvent, any Error>
}
