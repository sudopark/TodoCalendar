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

    @Test("미완료 투두 셀은 more action에 라이브액티비티 항목이 없어도 등록 여부가 달라지면 compare key가 달라진다")
    func uncompletedTodoCell_compareKeyIsDifferent_whenLiveActivityRegistrationChanged() {
        // given
        let cell = self.makeTodoCell(rawTime: .at(100)) |> \.isUncompletedTodo .~ true
        let registeredCell = self.makeTodoCell(rawTime: .at(100))
            |> \.isUncompletedTodo .~ true
            |> \.isLiveActivityRegistered .~ true

        // when + then
        #expect(cell.customCompareKey != registeredCell.customCompareKey)
    }
}

extension EventCellViewModelTests {

    @Test("시간 있는 todo 셀의 라이브액티비티 타겟은 .todo다 — 시간 없으면 nil")
    func todoCell_liveActivityTarget_dependsOnEventTime() {
        // given
        let cellWithTime = self.makeTodoCell(rawTime: .at(100))
        let cellWithoutTime = self.makeTodoCell(rawTime: nil)

        // when + then
        #expect(cellWithTime.liveActivityTarget == .todo(id: "todo"))
        #expect(cellWithoutTime.liveActivityTarget == nil)
    }

    @Test("schedule 셀의 라이브액티비티 타겟은 반복일 때만 회차 키를 싣는다 — 시간 없으면 nil")
    func scheduleCell_liveActivityTargetTurnKey_dependsOnRepeating() {
        // given
        let repeatingCell = ScheduleEventCellViewModel("schedule", turn: 1, name: "name", isRepeating: true)
            |> \.eventTimeRawValue .~ .at(100)
        let nonRepeatingCell = ScheduleEventCellViewModel("schedule", turn: 1, name: "name", isRepeating: false)
            |> \.eventTimeRawValue .~ .at(100)
        let noTimeCell = self.makeScheduleCell(rawTime: nil)

        // when + then
        #expect(repeatingCell.liveActivityTarget == .schedule(id: "schedule", turnKey: EventTime.at(100).customKey))
        #expect(nonRepeatingCell.liveActivityTarget == .schedule(id: "schedule", turnKey: nil))
        #expect(noTimeCell.liveActivityTarget == nil)
    }

    @Test("holiday 셀의 라이브액티비티 타겟은 uuid와 dateString을 싣는다")
    func holidayCell_liveActivityTarget() {
        // given
        let holiday = HolidayCalendarEvent(
            .init(uuid: "holiday", dateString: "2023-02-03", name: "dummy"), in: self.timeZone
        )!
        let cell = HolidayEventCellViewModel(holiday)

        // when + then
        #expect(cell.liveActivityTarget == .holiday(uuid: "holiday", dateString: "2023-02-03"))
    }

    @Test("시간 있는 todo의 moreActions는 라이브액티비티 토글을 담고 등록 여부를 반영한다 — 시간 없으면 안 담는다")
    func todoCell_moreActionsContainsLiveActivityToggle_whenTimeExists() {
        // given
        let cellWithTime = self.makeTodoCell(rawTime: .at(100))
        let registeredCellWithTime = cellWithTime |> \.isLiveActivityRegistered .~ true
        let cellWithoutTime = self.makeTodoCell(rawTime: nil)

        // when + then
        #expect(cellWithTime.moreActions?.basicActions.contains(.toggleLiveActivity(isRegistered: false)) == true)
        #expect(registeredCellWithTime.moreActions?.basicActions.contains(.toggleLiveActivity(isRegistered: true)) == true)
        #expect(cellWithoutTime.moreActions?.basicActions.contains(where: { if case .toggleLiveActivity = $0 { return true } else { return false } }) == false)
    }

    @Test("holiday의 moreActions는 라이브액티비티 토글 하나만 담는다")
    func holidayCell_moreActionsHasOnlyLiveActivityToggle() {
        // given
        let holiday = HolidayCalendarEvent(
            .init(uuid: "holiday", dateString: "2023-02-03", name: "dummy"), in: self.timeZone
        )!
        let cell = HolidayEventCellViewModel(holiday)

        // when + then
        #expect(cell.moreActions?.basicActions == [.toggleLiveActivity(isRegistered: false)])
        #expect(cell.moreActions?.removeActions == [])
    }

    @Test("시간 있는 todo 셀이라도 isUncompletedTodo면 moreActions는 라이브액티비티 토글을 안 담는다")
    func todoCell_moreActionsExcludesLiveActivityToggle_whenUncompletedTodo() {
        // given
        let uncompletedCell = self.makeTodoCell(rawTime: .at(100))
            |> \.isUncompletedTodo .~ true

        // when + then
        #expect(uncompletedCell.moreActions?.basicActions.contains(where: { if case .toggleLiveActivity = $0 { return true } else { return false } }) == false)
    }

    @Test("apple 셀의 라이브액티비티 타겟은 인스턴스 eventId를 쓴다 — 마스터(originalEventId)가 아니다")
    func appleCell_liveActivityTarget_usesInstanceEventIdNotMaster() {
        // given
        let raw = AppleCalendar.Event(
            eventId: "master-1#occ:100", originalEventId: "master-1", calendarId: "calendar",
            name: "name", eventTime: .at(100)
        )
        let event = AppleCalendarEvent(raw, in: self.timeZone, isWritable: true)
        let cell = AppleCalendarEventCellViewModel(event, in: self.todayRange, self.timeZone, true)

        // when + then
        #expect(cell?.liveActivityTarget == .appleCalendar(calendarId: "calendar", eventId: "master-1#occ:100"))
    }

    @Test("apple 셀의 moreActions는 라이브액티비티 토글을 공유 앞에 담고 등록 여부를 반영한다")
    func appleCell_moreActionsContainsLiveActivityToggleBeforeShare() {
        // given
        let cell = self.makeAppleCell(isWritable: true)
        let registeredCell = cell.map { $0 |> \.isLiveActivityRegistered .~ true }

        // when + then
        #expect(cell?.moreActions?.basicActions == [.toggleLiveActivity(isRegistered: false), .share])
        #expect(registeredCell?.moreActions?.basicActions == [.toggleLiveActivity(isRegistered: true), .share])
    }

    @Test("google 셀의 라이브액티비티 타겟은 인스턴스 eventId를 쓴다 — 시리즈 마스터(recurringEventId)가 아니다")
    func googleCell_liveActivityTarget_usesInstanceEventIdNotMaster() {
        // given
        let raw = GoogleCalendar.Event(
            "instance-1", "calendar", accountId: "account", name: "name", colorId: "color", time: .at(100)
        )
        |> \.recurringEventId .~ "master-1"
        let event = GoogleCalendarEvent(raw, in: self.timeZone, isWritable: true)
        let cell = GoogleCalendarEventCellViewModel(event, in: self.todayRange, self.timeZone, true)

        // when + then
        #expect(cell?.liveActivityTarget == .googleCalendar(accountId: "account", calendarId: "calendar", eventId: "instance-1"))
    }

    @Test("google 셀의 moreActions는 라이브액티비티 토글을 공유 앞에 담고 등록 여부를 반영한다")
    func googleCell_moreActionsContainsLiveActivityToggleBeforeShare() {
        // given
        let cell = self.makeGoogleCell()
        let registeredCell = cell.map { $0 |> \.isLiveActivityRegistered .~ true }

        // when + then
        #expect(cell?.moreActions?.basicActions == [.toggleLiveActivity(isRegistered: false), .share])
        #expect(registeredCell?.moreActions?.basicActions == [.toggleLiveActivity(isRegistered: true), .share])
    }
}
