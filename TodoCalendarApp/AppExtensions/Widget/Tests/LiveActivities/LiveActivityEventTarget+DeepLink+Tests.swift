//
//  LiveActivityEventTarget+DeepLink+Tests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
@testable import TodoCalendarAppWidget


struct LiveActivityEventTargetDeepLinkTests {

    @Test
    func todoTarget_buildsTodoDetailLink() {
        // given
        let target = LiveActivityEventTarget.todo(id: "t1")

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: nil)

        // then
        #expect(url?.eventPathComponents == ["event", "todo"])
        #expect(url?.eventQueryParams == ["event_id": "t1"])
    }

    @Test
    func scheduleTarget_buildsScheduleDetailLink_fromScheduleTimeQuery() {
        // given
        let target = LiveActivityEventTarget.schedule(id: "s1", turnKey: "999")
        let scheduleTimeQuery = EventTime.at(100).queryParams

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: scheduleTimeQuery)

        // then
        #expect(url?.eventPathComponents == ["event", "schedule"])
        #expect(url?.eventQueryParams == ["event_id": "s1", "at": "100.0"])
    }

    @Test
    func scheduleTarget_whenTimeQueryIsPeriod_buildsPeriodQuery() {
        // given
        let target = LiveActivityEventTarget.schedule(id: "s6", turnKey: nil)
        let time = EventTime.period(1_755_400_800..<1_755_404_400)
        let scheduleTimeQuery = time.queryParams

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: scheduleTimeQuery)

        // then
        #expect(url?.eventPathComponents == ["event", "schedule"])
        #expect(url?.eventQueryParams == [
            "event_id": "s6",
            "start": "1755400800.0",
            "end": "1755404400.0"
        ])
    }

    @Test
    func scheduleTarget_whenTimeQueryIsAllDay_buildsAllDayQuery() {
        // given
        let target = LiveActivityEventTarget.schedule(id: "s2", turnKey: nil)
        let time = EventTime.allDay(1_755_400_800..<1_755_487_200, secondsFromGMT: 32_400)
        let scheduleTimeQuery = time.queryParams

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: scheduleTimeQuery)

        // then
        #expect(url?.eventPathComponents == ["event", "schedule"])
        #expect(url?.eventQueryParams == [
            "event_id": "s2",
            "start": "1755400800.0",
            "end": "1755487200.0",
            "offset": "32400.0",
            "isAllDay": "true"
        ])
    }

    @Test
    func scheduleTarget_whenScheduleTimeQueryMissing_returnsNil() {
        // given
        let target = LiveActivityEventTarget.schedule(id: "s3", turnKey: nil)

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: nil)

        // then
        #expect(url == nil)
    }

    @Test
    func scheduleTarget_whenScheduleTimeQueryMalformed_returnsNil() {
        // given
        let target = LiveActivityEventTarget.schedule(id: "s4", turnKey: nil)

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: ["foo": "bar"])

        // then
        #expect(url == nil)
    }

    @Test
    func holidayTarget_buildsHolidayDetailLink() {
        // given
        let target = LiveActivityEventTarget.holiday(uuid: "h1", dateString: "2026-08-17")

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: nil)

        // then
        #expect(url?.eventPathComponents == ["event", "holiday"])
        #expect(url?.eventQueryParams == ["event_id": "h1"])
    }

    @Test
    func googleTarget_buildsGoogleDetailLink() {
        // given
        let target = LiveActivityEventTarget.googleCalendar(accountId: "acc1", calendarId: "cal1", eventId: "evt1")

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: nil)

        // then
        #expect(url?.eventPathComponents == ["event", "google"])
        #expect(url?.eventQueryParams == ["event_id": "evt1", "calendar_id": "cal1", "account_id": "acc1"])
    }

    @Test
    func appleTarget_buildsAppleDetailLink() {
        // given
        let target = LiveActivityEventTarget.appleCalendar(calendarId: "cal1", eventId: "evt1")

        // when
        let url = target.eventDetailURL(scheduleTimeQuery: nil)

        // then
        #expect(url?.eventPathComponents == ["event", "apple"])
        #expect(url?.eventQueryParams == ["event_id": "evt1", "calendar_id": "cal1"])
    }

    @Test
    func activityViewModel_exposesDeepLinkFromTargetAndState() {
        // given
        let target = LiveActivityEventTarget.schedule(id: "s5", turnKey: nil)
        let scheduleTimeQuery = EventTime.at(500).queryParams
        let attributes = EventCountdownActivityAttributes(target: target)
        let state = EventCountdownActivityAttributes.State(
            eventName: "회의", eventTimeText: "오후 2:00",
            tagColorHex: "#2FB457", eventDate: .now, startDate: .now,
            scheduleTimeQuery: scheduleTimeQuery
        )

        // when
        let viewModel = EventCountdownActivityViewModel(attributes, state)

        // then
        #expect(viewModel.deepLink?.eventPathComponents == ["event", "schedule"])
        #expect(viewModel.deepLink?.eventQueryParams == ["event_id": "s5", "at": "500.0"])
    }

    @Test
    func activityViewModel_exposesDeepLinkFromTargetAndState_periodTime() {
        // given
        let target = LiveActivityEventTarget.schedule(id: "s7", turnKey: nil)
        let time = EventTime.period(1_755_400_800..<1_755_404_400)
        let attributes = EventCountdownActivityAttributes(target: target)
        let state = EventCountdownActivityAttributes.State(
            eventName: "회의", eventTimeText: "오후 2:00",
            tagColorHex: "#2FB457", eventDate: .now, startDate: .now,
            scheduleTimeQuery: time.queryParams
        )

        // when
        let viewModel = EventCountdownActivityViewModel(attributes, state)

        // then
        #expect(viewModel.deepLink?.eventPathComponents == ["event", "schedule"])
        #expect(viewModel.deepLink?.eventQueryParams == [
            "event_id": "s7", "start": "1755400800.0", "end": "1755404400.0"
        ])
    }
}


private extension URL {

    var eventPathComponents: [String] {
        self.path.components(separatedBy: "/").filter { !$0.isEmpty }
    }

    var eventQueryParams: [String: String] {
        URLComponents(url: self, resolvingAgainstBaseURL: true)?
            .queryItems?
            .reduce(into: [String: String]()) { acc, item in acc[item.name] = item.value }
            ?? [:]
    }
}
