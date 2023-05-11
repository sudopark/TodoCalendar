//
//  StubScheduleEventRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/05/01.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import Domain


class StubScheduleEventRepository: ScheduleEventRepository, BaseStub {
    
    var shouldFailMake: Bool = false
    func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        try self.checkShouldFail(self.shouldFailMake)
        return ScheduleEvent(uuid: "new", name: params.name ?? "", time: params.time ?? .at(.dummy()))
            |> \.eventTagId .~ params.eventTagId
            |> \.repeating .~ params.repeating
    }
    
    var updateOriginEventMocking: ScheduleEvent?
    
    var shouldFailUpdate: Bool = false
    func updateScheduleEvent(_ eventId: String, _ params: ScheduleEditParams) async throws -> ScheduleEvent {
        try self.checkShouldFail(self.shouldFailUpdate)
        return ScheduleEvent(uuid: eventId, name: params.name ?? "", time: params.time ?? .at(.dummy()))
            |> \.eventTagId .~ (params.eventTagId ?? self.updateOriginEventMocking?.eventTagId)
            |> \.repeating .~ (params.repeating ?? self.updateOriginEventMocking?.repeating)
            |> \.showTurn .~ (params.showTurn ?? self.updateOriginEventMocking?.showTurn ?? false)
    }
    
    var shouldFailExclude: Bool = false
    func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime,
        asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult {
        
        try self.checkShouldFail(self.shouldFailExclude)
        
        let newEvent = ScheduleEvent(uuid: "new", name: params.name ?? "", time: params.time ?? .at(.dummy()))
            |> \.eventTagId .~ params.eventTagId
            |> \.repeating .~ params.repeating
            |> \.showTurn .~ (params.showTurn ?? false)
        
        let originEvent = (
            updateOriginEventMocking ?? ScheduleEvent(uuid: originEventId, name: "origin", time: .at(.dummy(0)))
        )
        |> \.repeatingTimeToExcludes .~ [currentTime.customKey]
        
        return .init(newEvent: newEvent, originEvent: originEvent)
    }
    
    var shouldFailLoad: Bool = false
    var eventsMocking: (Range<TimeStamp>) -> [ScheduleEvent] = { range in
        
        var sender: [ScheduleEvent] = []
        let oneDay: TimeInterval = 3600 * 24
        let days = ((range.upperBound.utcTimeInterval - range.lowerBound.utcTimeInterval) / oneDay) |> Int.init
        return (0..<days).map {
            let time = range.lowerBound.add(oneDay)
            return ScheduleEvent(uuid: "id:\($0)", name: "name:\($0)", time: .at(time))
        }
    }
    func loadScheduleEvents(in range: Range<TimeStamp>) -> AnyPublisher<[ScheduleEvent], Error> {
        guard self.shouldFailLoad == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        return Just(self.eventsMocking(range)).mapNever().eraseToAnyPublisher()
    }
}
