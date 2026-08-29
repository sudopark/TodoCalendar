//
//  GoogleCalendarEventTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


@Suite("GoogleCalendarEventTests")
struct GoogleCalendarEventTests {

    private func makeOrigin(recurringEventId: String?) -> GoogleCalendar.EventOrigin {
        var origin = GoogleCalendar.EventOrigin(id: "event1", summary: "event")
        origin.start = .init() |> \.dateTime .~ "2023-03-05T00:00:00+09:00"
        origin.end = .init() |> \.dateTime .~ "2023-03-06T00:00:00+09:00"
        origin.recurringEventId = recurringEventId
        return origin
    }
}

extension GoogleCalendarEventTests {

    @Test func event_whenOriginHasRecurringEventId_carriesIt() throws {
        // given
        let origin = self.makeOrigin(recurringEventId: "master-1")

        // when
        let event = try #require(
            GoogleCalendar.Event(origin, "calendar", accountId: "account", nil)
        )

        // then
        #expect(event.recurringEventId == "master-1")
    }

    @Test func event_whenOriginHasNoRecurringEventId_isNil() throws {
        // given
        let origin = self.makeOrigin(recurringEventId: nil)

        // when
        let event = try #require(
            GoogleCalendar.Event(origin, "calendar", accountId: "account", nil)
        )

        // then
        #expect(event.recurringEventId == nil)
    }
}
