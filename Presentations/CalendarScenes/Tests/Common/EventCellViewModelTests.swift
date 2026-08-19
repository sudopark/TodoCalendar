//
//  EventCellViewModelTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain

@testable import CalendarScenes


class EventCellViewModelTests {

    private let timeZone = TimeZone(abbreviation: "UTC")!
    private let todayRange: Range<TimeInterval> = 0..<24*3600

    private func makeTodoCell(rawTime: EventTime?) -> TodoEventCellViewModel {
        return TodoEventCellViewModel("todo", name: "name")
            |> \.eventTimeRawValue .~ rawTime
    }

    private func makeScheduleCell(rawTime: EventTime?) -> ScheduleEventCellViewModel {
        return ScheduleEventCellViewModel("schedule", turn: 1, name: "name")
            |> \.eventTimeRawValue .~ rawTime
    }

    private func makeGoogleCell(
        accountId: String = "account",
        recurringEventId: String? = nil,
        isWritable: Bool = false
    ) -> GoogleCalendarEventCellViewModel? {
        let raw = GoogleCalendar.Event(
            "google", "calendar",
            accountId: accountId, name: "name", colorId: "color",
            time: .at(100)
        )
        |> \.recurringEventId .~ recurringEventId
        let event = GoogleCalendarEvent(raw, in: self.timeZone, isWritable: isWritable)
        return GoogleCalendarEventCellViewModel(
            event, in: self.todayRange, self.timeZone, true
        )
    }

    private func makeAppleCell(isWritable: Bool) -> AppleCalendarEventCellViewModel? {
        let raw = AppleCalendar.Event(
            eventId: "apple", originalEventId: "apple", calendarId: "calendar",
            name: "name", eventTime: .at(100)
        )
        let event = AppleCalendarEvent(raw, in: self.timeZone, isWritable: isWritable)
        return AppleCalendarEventCellViewModel(
            event, in: self.todayRange, self.timeZone, true
        )
    }
}

extension EventCellViewModelTests {

    @Test("셀이 그리는 값과 동작에 쓰는 값이 모두 같으면 compare key도 같다")
    func cell_compareKeyIsSame_whenAllValuesAreSame() {
        // given
        let (todo, sameTodo) = (self.makeTodoCell(rawTime: .at(100)), self.makeTodoCell(rawTime: .at(100)))
        let (schedule, sameSchedule) = (self.makeScheduleCell(rawTime: .at(100)), self.makeScheduleCell(rawTime: .at(100)))
        let (google, sameGoogle) = (self.makeGoogleCell(accountId: "account"), self.makeGoogleCell(accountId: "account"))

        // when + then
        #expect(todo.customCompareKey == sameTodo.customCompareKey)
        #expect(schedule.customCompareKey == sameSchedule.customCompareKey)
        #expect(google?.customCompareKey == sameGoogle?.customCompareKey)
    }

    @Test("todo 셀은 표시 텍스트에 안 드러나는 raw event time이 달라져도 compare key가 달라진다")
    func todoCell_compareKeyIsDifferent_whenRawEventTimeChanged() {
        // given
        let cell = self.makeTodoCell(rawTime: .at(100))
        let timeChangedCell = self.makeTodoCell(rawTime: .at(200))

        // when + then
        #expect(cell.customCompareKey != timeChangedCell.customCompareKey)
    }

    @Test("schedule 셀은 표시 텍스트에 안 드러나는 raw event time이 달라져도 compare key가 달라진다")
    func scheduleCell_compareKeyIsDifferent_whenRawEventTimeChanged() {
        // given
        let cell = self.makeScheduleCell(rawTime: .at(100))
        let timeChangedCell = self.makeScheduleCell(rawTime: .at(200))

        // when + then
        #expect(cell.customCompareKey != timeChangedCell.customCompareKey)
    }

    @Test("google 셀은 표시에 안 쓰이는 account id가 달라져도 compare key가 달라진다")
    func googleCell_compareKeyIsDifferent_whenAccountIdChanged() {
        // given
        let cell = self.makeGoogleCell(accountId: "account")
        let accountChangedCell = self.makeGoogleCell(accountId: "another-account")

        // when + then
        #expect(cell?.customCompareKey != accountChangedCell?.customCompareKey)
    }

    @Test("google 셀은 둘 다 반복 이벤트라도 시리즈 마스터 id가 다르면 compare key가 달라진다")
    func googleCell_compareKeyIsDifferent_whenRecurringEventIdChanged() {
        // given
        let cell = self.makeGoogleCell(recurringEventId: "master-1")
        let recurringEventIdChangedCell = self.makeGoogleCell(recurringEventId: "master-2")

        // when + then
        #expect(cell?.customCompareKey != recurringEventIdChangedCell?.customCompareKey)
    }

    @Test("google 셀은 표시에 안 쓰이는 isWritable이 달라져도 compare key가 달라진다")
    func googleCell_compareKeyIsDifferent_whenIsWritableChanged() {
        // given
        let cell = self.makeGoogleCell(isWritable: false)
        let writableChangedCell = self.makeGoogleCell(isWritable: true)

        // when + then
        #expect(cell?.customCompareKey != writableChangedCell?.customCompareKey)
    }

    @Test("apple 셀은 표시에 안 쓰이는 isWritable이 달라져도 compare key가 달라진다")
    func appleCell_compareKeyIsDifferent_whenIsWritableChanged() {
        // given
        let cell = self.makeAppleCell(isWritable: false)
        let writableChangedCell = self.makeAppleCell(isWritable: true)

        // when + then
        #expect(cell?.customCompareKey != writableChangedCell?.customCompareKey)
    }
}
