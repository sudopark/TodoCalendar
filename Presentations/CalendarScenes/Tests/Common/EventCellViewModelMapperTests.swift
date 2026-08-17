//
//  EventCellViewModelMapperTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import CalendarScenes


final class EventCellViewModelMapperTests {

    private let timeZone = TimeZone(abbreviation: "UTC")!
    private let todayRange: Range<TimeInterval> = 0..<24*3600

    private func makeMapper() -> EventCellViewModelMapper {
        return EventCellViewModelMapper(
            range: self.todayRange, timeZone: self.timeZone, is24hourForm: true
        )
    }

    private func makeTodoEvent(_ id: String) -> TodoCalendarEvent {
        let todo = TodoEvent(uuid: id, name: "name")
        return TodoCalendarEvent(todo, in: self.timeZone)
    }

    private func makeScheduleEvent(_ id: String) -> ScheduleCalendarEvent {
        let schedule = ScheduleEvent(uuid: id, name: "name", time: .at(100))
        return ScheduleCalendarEvent.events(from: schedule, in: self.timeZone).first!
    }

    private func makeHolidayEvent(_ id: String) -> HolidayCalendarEvent {
        let holiday = Holiday(uuid: id, dateString: "2026-08-17", name: "name")
        return HolidayCalendarEvent(holiday, in: self.timeZone)!
    }

    private func makeGoogleEvent(_ id: String) -> GoogleCalendarEvent {
        let raw = GoogleCalendar.Event(
            id, "calendar",
            accountId: "account", name: "name", colorId: "color",
            time: .at(100)
        )
        return GoogleCalendarEvent(raw, in: self.timeZone)
    }

    private func makeAppleEvent(_ id: String) -> AppleCalendarEvent {
        let raw = AppleCalendar.Event(
            eventId: id,
            originalEventId: id,
            calendarId: "calendar",
            name: "name",
            eventTime: .at(100)
        )
        return AppleCalendarEvent(raw, in: self.timeZone)
    }

    private struct UnknownCalendarEvent: CalendarEvent {
        let eventId: String = "unknown"
        let name: String = "unknown"
        let eventTime: EventTime? = nil
        let eventTimeOnCalendar: EventTimeOnCalendar? = nil
        let eventTagId: EventTagId = .default
        let isForemost: Bool = false
        let isRepeating: Bool = false
        var locationText: String?
    }
}

extension EventCellViewModelMapperTests {

    @Test func mapper_fromTodoCalendarEvent_returnsTodoCellViewModel() {
        // given
        let mapper = self.makeMapper()
        let event = self.makeTodoEvent("todo1")

        // when
        let cell = mapper.cellViewModel(from: event)

        // then
        #expect(cell is TodoEventCellViewModel)
        #expect(cell?.eventIdentifier == "todo1")
    }

    @Test func mapper_fromScheduleCalendarEvent_returnsScheduleCellViewModel() {
        // given
        let mapper = self.makeMapper()
        let event = self.makeScheduleEvent("schedule1")

        // when
        let cell = mapper.cellViewModel(from: event)

        // then
        #expect(cell is ScheduleEventCellViewModel)
        #expect(cell?.eventIdentifier == event.eventId)
    }

    @Test func mapper_fromHolidayCalendarEvent_returnsHolidayCellViewModel() {
        // given
        let mapper = self.makeMapper()
        let event = self.makeHolidayEvent("holiday1")

        // when
        let cell = mapper.cellViewModel(from: event)

        // then
        #expect(cell is HolidayEventCellViewModel)
        #expect(cell?.eventIdentifier == "holiday1")
    }

    @Test func mapper_fromGoogleCalendarEvent_returnsGoogleCellViewModel() {
        // given
        let mapper = self.makeMapper()
        let event = self.makeGoogleEvent("google1")

        // when
        let cell = mapper.cellViewModel(from: event)

        // then
        #expect(cell is GoogleCalendarEventCellViewModel)
        #expect(cell?.eventIdentifier == "google1")
    }

    @Test func mapper_fromAppleCalendarEvent_returnsAppleCellViewModel() {
        // given
        let mapper = self.makeMapper()
        let event = self.makeAppleEvent("apple1")

        // when
        let cell = mapper.cellViewModel(from: event)

        // then
        #expect(cell is AppleCalendarEventCellViewModel)
        #expect(cell?.eventIdentifier == "apple1")
    }

    @Test func mapper_fromUnknownEvent_returnsNil() {
        // given
        let mapper = self.makeMapper()
        let event = UnknownCalendarEvent()

        // when
        let cell = mapper.cellViewModel(from: event)

        // then
        #expect(cell == nil)
    }

    @Test func mapper_fromEvents_skipsUnmappableOnes() {
        // given
        let mapper = self.makeMapper()
        let events: [any CalendarEvent] = [
            self.makeTodoEvent("todo1"),
            UnknownCalendarEvent(),
            self.makeScheduleEvent("schedule1")
        ]

        // when
        let cells = mapper.cellViewModels(from: events)

        // then
        #expect(cells.count == 2)
    }
}
