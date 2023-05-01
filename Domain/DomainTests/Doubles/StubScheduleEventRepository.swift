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
            |> \.repeatingOption .~ params.repeatingOption
    }
    
    var shouldFailLoad: Bool = false
    var eventsMocking: (Range<TimeStamp>) -> [ScheduleEvent] = { _ in
        return (-10..<10).map {
            ScheduleEvent(uuid: "id:\($0)", name: "name:\($0)", time: .at(.dummy($0)))
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
