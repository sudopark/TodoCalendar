//
//  StubAppleCalendarRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


open class StubAppleCalendarRepository: AppleCalendarRepository, @unchecked Sendable {

    public init() { }

    public var stubCalendarTags: [AppleCalendar.Tag] = (0..<3).map {
        .init(id: "cal:\($0)", name: "Calendar \($0)", colorHex: nil)
    }
    open func loadCalendarTags() -> AnyPublisher<[AppleCalendar.Tag], any Error> {
        return Just(stubCalendarTags)
            .setFailureType(to: (any Error).self)
            .eraseToAnyPublisher()
    }

    public var stubEvents: [AppleCalendar.Event] = []
    public var didLoadEvents = false
    open func loadEvents(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[AppleCalendar.Event], any Error> {
        didLoadEvents = true
        return Just(stubEvents)
            .setFailureType(to: (any Error).self)
            .eraseToAnyPublisher()
    }

    public var stubEventOrigin: AppleCalendar.EventOrigin?
    open func loadEventOrigin(id: String) -> AnyPublisher<AppleCalendar.EventOrigin?, Never> {
        if let stubEventOrigin {
            return Just(stubEventOrigin).eraseToAnyPublisher()
        }
        let origin = stubEvents.first(where: { $0.eventId == id }).map { event in
            AppleCalendar.EventOrigin(
                eventId: event.eventId, originalEventId: event.originalEventId,
                calendarId: event.calendarId, name: event.name, eventTime: event.eventTime
            )
        }
        return Just(origin).eraseToAnyPublisher()
    }

    public var didResetCache = false
    open func resetCache() async throws {
        didResetCache = true
    }
}
