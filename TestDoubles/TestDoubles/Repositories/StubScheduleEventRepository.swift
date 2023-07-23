//
//  StubScheduleEventRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/02.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit


open class StubScheduleEventRepository: ScheduleEventRepository, BaseStub {
    
    public init() { }
    
    public var shouldFailMake: Bool = false
    open func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        try self.checkShouldFail(self.shouldFailMake)
        return ScheduleEvent(uuid: "new", name: params.name ?? "", time: params.time ?? .at(0))
            |> \.eventTagId .~ params.eventTagId
            |> \.repeating .~ params.repeating
    }
    
    public var updateOriginEventMocking: ScheduleEvent?
    
    public var shouldFailUpdate: Bool = false
    open func updateScheduleEvent(_ eventId: String, _ params: ScheduleEditParams) async throws -> ScheduleEvent {
        try self.checkShouldFail(self.shouldFailUpdate)
        let time: EventTime = params.time ?? .at(0)
        let eventTagId: String? = params.eventTagId ?? self.updateOriginEventMocking?.eventTagId
        let repeating: EventRepeating? = params.repeating ?? self.updateOriginEventMocking?.repeating
        let showTurn: Bool = params.showTurn ?? self.updateOriginEventMocking?.showTurn ?? false
        return ScheduleEvent(uuid: eventId, name: params.name ?? "", time: time)
            |> \.eventTagId .~ eventTagId
            |> \.repeating .~ repeating
            |> \.showTurn .~ showTurn
    }
    
    public var shouldFailExclude: Bool = false
    open func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime,
        asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult {
        
        try self.checkShouldFail(self.shouldFailExclude)
        
        let newEvent = ScheduleEvent(uuid: "new", name: params.name ?? "", time: params.time ?? .at(0))
            |> \.eventTagId .~ params.eventTagId
            |> \.repeating .~ params.repeating
            |> \.showTurn .~ (params.showTurn ?? false)
        
        let originEvent = (
            updateOriginEventMocking ?? ScheduleEvent(uuid: originEventId, name: "origin", time: .at(0))
        )
        |> \.repeatingTimeToExcludes .~ [currentTime.customKey]
        
        return .init(newEvent: newEvent, originEvent: originEvent)
    }
    
    public var shouldFailLoad: Bool = false
    public var eventsMocking: (Range<TimeInterval>) -> [ScheduleEvent] = { range in
        
        var sender: [ScheduleEvent] = []
        let oneDay: TimeInterval = 3600 * 24
        let days = ((range.upperBound - range.lowerBound) / oneDay) |> Int.init
        return (0..<days).map {
            let time = range.lowerBound + oneDay
            return ScheduleEvent(uuid: "id:\($0)", name: "name:\($0)", time: .at(time))
        }
    }
    open func loadScheduleEvents(in range: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], Error> {
        guard self.shouldFailLoad == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        return Just(self.eventsMocking(range)).mapNever().eraseToAnyPublisher()
    }
}
