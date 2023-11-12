//
//  ScheduleEventRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/05/01.
//

import Foundation
import Combine


public protocol ScheduleEventRepository {
    
    func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent
    
    func updateScheduleEvent(_ eventId: String, _ params: ScheduleEditParams) async throws -> ScheduleEvent
    
    func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime,
        asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult
    
    func removeEvent(
        _ eventId: String, onlyThisTime: EventTime?
    ) async throws -> RemoveSheduleEventResult
    
    func loadScheduleEvents(in range: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], any Error>
    
    func scheduleEvent(_ eventId: String) -> AnyPublisher<ScheduleEvent, any Error>
}
