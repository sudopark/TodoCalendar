//
//  CalendarEventTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import CalendarScenes


class CalendarEventTests {

    private let timeZone = TimeZone(abbreviation: "UTC")!

    private func makeGoogleEvent(
        calendarId: String = "calendar",
        accountId: String = "account"
    ) -> GoogleCalendarEvent {
        let raw = GoogleCalendar.Event(
            "google", calendarId,
            accountId: accountId, name: "name", colorId: "color",
            time: .at(100)
        )
        return GoogleCalendarEvent(raw, in: self.timeZone)
    }

    private func makeAppleEvent(calendarId: String = "calendar") -> AppleCalendarEvent {
        let raw = AppleCalendar.Event(
            eventId: "apple",
            originalEventId: "apple",
            calendarId: calendarId,
            name: "name",
            eventTime: .at(100)
        )
        return AppleCalendarEvent(raw, in: self.timeZone)
    }
}

extension CalendarEventTests {

    @Test("외부 캘린더 이벤트는 모든 값이 같으면 compare key도 같다")
    func externalEvent_compareKeyIsSame_whenAllValuesAreSame() {
        // given
        let (google, sameGoogle) = (self.makeGoogleEvent(), self.makeGoogleEvent())
        let (apple, sameApple) = (self.makeAppleEvent(), self.makeAppleEvent())

        // when + then
        #expect(google.compareKey == sameGoogle.compareKey)
        #expect(apple.compareKey == sameApple.compareKey)
    }

    @Test("google 이벤트는 계정이 달라지면 compare key도 달라진다")
    func googleEvent_compareKeyIsDifferent_whenAccountIdChanged() {
        // given
        let event = self.makeGoogleEvent(accountId: "account")
        let accountChangedEvent = self.makeGoogleEvent(accountId: "another-account")

        // when + then
        #expect(event.compareKey != accountChangedEvent.compareKey)
    }

    @Test("google 이벤트는 소속 캘린더가 달라지면 compare key도 달라진다")
    func googleEvent_compareKeyIsDifferent_whenCalendarIdChanged() {
        // given
        let event = self.makeGoogleEvent(calendarId: "calendar")
        let calendarChangedEvent = self.makeGoogleEvent(calendarId: "another-calendar")

        // when + then
        #expect(event.compareKey != calendarChangedEvent.compareKey)
    }

    @Test("apple 이벤트는 소속 캘린더가 달라지면 compare key도 달라진다")
    func appleEvent_compareKeyIsDifferent_whenCalendarIdChanged() {
        // given
        let event = self.makeAppleEvent(calendarId: "calendar")
        let calendarChangedEvent = self.makeAppleEvent(calendarId: "another-calendar")

        // when + then
        #expect(event.compareKey != calendarChangedEvent.compareKey)
    }
}
