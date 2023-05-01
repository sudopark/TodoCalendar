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
import Domain
import Extensions
import UnitTestHelpKit

class StubScheduleEventRepository: ScheduleEventRepository, BaseStub {
    
    var shouldFailMake: Bool = false
    func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        try self.checkShouldFail(self.shouldFailMake)
        return ScheduleEvent(uuid: "new", name: params.name ?? "", time: params.time ?? .at(.dummy()))
            |> \.eventTagId .~ params.eventTagId
            |> \.repeating .~ params.repeating
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
