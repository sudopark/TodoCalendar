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

extension GoogleCalendarEventTests {

    @Test(
        "response status 문자열을 도메인 enum 으로",
        arguments: [
            ("accepted", GoogleCalendar.AttendeeResponseStatus.accepted),
            ("declined", GoogleCalendar.AttendeeResponseStatus.declined),
            ("tentative", GoogleCalendar.AttendeeResponseStatus.tentative),
            ("needsAction", GoogleCalendar.AttendeeResponseStatus.needsAction)
        ]
    )
    func attendee_responseStatusMapsToDomainEnum(
        _ pair: (String, GoogleCalendar.AttendeeResponseStatus)
    ) throws {
        // given
        let attendee = GoogleCalendar.EventOrigin.Attendee()
            |> \.responseStatus .~ pair.0

        // when
        let response = attendee.response

        // then
        #expect(response == pair.1)
    }

    @Test func attendee_responseStatus_whenUnsupportedString_isNil() throws {
        // given
        let attendee = GoogleCalendar.EventOrigin.Attendee()
            |> \.responseStatus .~ "unknown_status"

        // when
        let response = attendee.response

        // then
        #expect(response == nil)
    }

    @Test(
        "selfValue 를 isSelf 로 그대로 반영",
        arguments: [
            (true, true), (false, false)
        ]
    )
    func attendee_isSelf_reflectsSelfValue(_ pair: (Bool, Bool)) throws {
        // given
        let attendee = GoogleCalendar.EventOrigin.Attendee()
            |> \.selfValue .~ pair.0

        // when
        let isSelf = attendee.isSelf

        // then
        #expect(isSelf == pair.1)
    }

    @Test func attendee_isSelf_whenSelfValueIsNil_isFalse() throws {
        // given
        let attendee = GoogleCalendar.EventOrigin.Attendee()

        // when
        let isSelf = attendee.isSelf

        // then
        #expect(isSelf == false)
    }

    @Test func editParams_isNotEmpty_whenOnlyAttendeesSet() throws {
        // given
        let attendee = GoogleCalendar.EventOrigin.Attendee()
            |> \.email .~ "a@b.com"
        let params = GoogleCalendar.EventEditParams()
            |> \.attendees .~ [attendee]

        // when
        let isEmpty = params.isEmpty

        // then
        #expect(isEmpty == false)
    }
}
