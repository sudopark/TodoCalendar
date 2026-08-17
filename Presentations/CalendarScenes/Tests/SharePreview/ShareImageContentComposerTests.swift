//
//  ShareImageContentComposerTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import Extensions

@testable import CalendarScenes


final class ShareImageContentComposerTests {

    private let timeZone: TimeZone = TimeZone(abbreviation: "KST")!

    private var calendar: Calendar {
        return Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        return self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func dayRange(_ date: Date) -> Range<TimeInterval> {
        return self.calendar.dayRange(date)!
    }

    private func makeComposer(is24hourForm: Bool = true) -> ShareImageContentComposer {
        return ShareImageContentComposer(timeZone: self.timeZone, is24hourForm: is24hourForm)
    }

    private func scheduleEvent(_ id: String, at time: Date, durationHours: Int = 1) -> any CalendarEvent {
        let end = time.addingTimeInterval(TimeInterval(durationHours * 3600))
        let schedule = ScheduleEvent(
            uuid: id, name: id, time: .period(time.timeIntervalSince1970..<end.timeIntervalSince1970)
        )
        return ScheduleCalendarEvent.events(from: schedule, in: self.timeZone).first!
    }

    private func repeatingScheduleTurns(
        _ id: String, firstAt: Date, secondAt: Date
    ) -> [any CalendarEvent] {
        let schedule = ScheduleEvent(uuid: id, name: id, time: .at(firstAt.timeIntervalSince1970))
            |> \.nextRepeatingTimes .~ [.init(time: .at(secondAt.timeIntervalSince1970), turn: 2)]
        return ScheduleCalendarEvent.events(from: schedule, in: self.timeZone)
    }

    private func currentTodo(_ id: String, createdAt: TimeInterval) -> TodoCalendarEvent {
        let todo = TodoEvent(uuid: id, name: id) |> \.creatTimeStamp .~ createdAt
        return TodoCalendarEvent(current: todo, isForemost: false)
    }

    private func sections(of content: ShareImageContentModel) -> [ShareImageListSection]? {
        guard case let .list(sections) = content else { return nil }
        return sections
    }

    private func grid(of content: ShareImageContentModel) -> ShareImageMonthGrid? {
        guard case let .monthGrid(grid) = content else { return nil }
        return grid
    }
}


// MARK: - listContent: 날짜 헤더

extension ShareImageContentComposerTests {

    @Test func listContent_whenSingleDay_hasNoDayHeaderText() {
        // given
        let day = self.date(2026, 8, 10)
        let range = self.dayRange(day)
        let event = self.scheduleEvent("e1", at: day)
        let composer = self.makeComposer()

        // when
        let content = composer.listContent(
            events: [event], currentTodos: [], range: range,
            excludedEventIds: []
        )

        // then
        let sections = self.sections(of: content)
        #expect(sections?.count == 1)
        #expect(sections?.first?.dayHeaderText == nil)
        #expect(sections?.first?.lines.count == 1)
    }

    @Test func listContent_whenMultipleDays_setsDayHeaderTextPerSection() {
        // given
        let day10 = self.date(2026, 8, 10)
        let day12 = self.date(2026, 8, 12)
        let range = day10.timeIntervalSince1970..<self.dayRange(day12).upperBound
        let earlier = self.scheduleEvent("earlier", at: day10)
        let later = self.scheduleEvent("later", at: day12)
        let composer = self.makeComposer()

        // when
        let content = composer.listContent(
            events: [later, earlier], currentTodos: [], range: range,
            excludedEventIds: []
        )

        // then
        let sections = self.sections(of: content)
        #expect(sections?.count == 2)
        #expect(sections?.allSatisfy { $0.dayHeaderText != nil } == true)
        #expect(sections?.map { $0.dayStart } == [self.calendar.startOfDay(for: day10).timeIntervalSince1970, self.calendar.startOfDay(for: day12).timeIntervalSince1970])
        #expect(sections?.first?.lines.map { $0.eventId } == [earlier.eventId])
    }
}


// MARK: - listContent: undated todo 섹션

extension ShareImageContentComposerTests {

    @Test func listContent_putsUndatedTodosInFirstSection() {
        // given
        let day = self.date(2026, 8, 10)
        let range = self.dayRange(day)
        let datedEvent = self.scheduleEvent("dated", at: day)
        let earlierTodo = self.currentTodo("todo-earlier", createdAt: 100)
        let laterTodo = self.currentTodo("todo-later", createdAt: 200)
        let composer = self.makeComposer()

        // when
        let content = composer.listContent(
            events: [datedEvent], currentTodos: [laterTodo, earlierTodo], range: range,
            excludedEventIds: []
        )

        // then
        let sections = self.sections(of: content)
        #expect(sections?.first?.dayStart == nil)
        #expect(sections?.first?.lines.map { $0.eventId } == ["todo-earlier", "todo-later"])
        #expect(sections?.last?.lines.map { $0.eventId } == [datedEvent.eventId])
        #expect(sections?.last?.dayHeaderText == nil)
    }
}


// MARK: - listContent: range 밖 turn 제외

extension ShareImageContentComposerTests {

    @Test func listContent_excludesEventsOutOfRange() {
        // given
        let inRangeDay = self.date(2026, 8, 10)
        let outOfRangeDay = self.date(2026, 8, 20)
        let range = self.dayRange(inRangeDay)
        let turns = self.repeatingScheduleTurns("series", firstAt: inRangeDay, secondAt: outOfRangeDay)
        let composer = self.makeComposer()

        // when
        let content = composer.listContent(
            events: turns, currentTodos: [], range: range,
            excludedEventIds: []
        )

        // then
        let sections = self.sections(of: content)
        let allLineIds = sections?.flatMap { $0.lines.map { $0.eventId } } ?? []
        #expect(allLineIds == [turns[0].eventId])
    }
}


// MARK: - listContent: 제외 표시

extension ShareImageContentComposerTests {

    @Test func listContent_marksExcludedLines() {
        // given
        let day = self.date(2026, 8, 10)
        let range = self.dayRange(day)
        let e1 = self.scheduleEvent("e1", at: day, durationHours: 1)
        let e2 = self.scheduleEvent("e2", at: day.addingTimeInterval(3600 * 2), durationHours: 1)
        let composer = self.makeComposer()

        // when
        let content = composer.listContent(
            events: [e1, e2], currentTodos: [], range: range,
            excludedEventIds: [e1.eventId]
        )

        // then
        let lines = self.sections(of: content)?.first?.lines ?? []
        #expect(lines.first(where: { $0.eventId == e1.eventId })?.isExcluded == true)
        #expect(lines.first(where: { $0.eventId == e2.eventId })?.isExcluded == false)
    }
}


// MARK: - monthGridContent

extension ShareImageContentComposerTests {

    private func week(startingDay: Int, month: Int = 8, year: Int = 2026) -> CalendarComponent.Week {
        let days = (0..<7).map { offset in
            CalendarComponent.Day(year: year, month: month, day: startingDay + offset, weekDay: offset + 1)
        }
        return .init(days: days)
    }

    private func component(startingDays: [Int]) -> CalendarComponent {
        return .init(year: 2026, month: 8, weeks: startingDays.map { self.week(startingDay: $0) })
    }

    @Test func monthGridContent_buildsWeekRowsFromComponent() {
        // given
        let component = self.component(startingDays: [3, 10])
        let event = self.scheduleEvent("e1", at: self.date(2026, 8, 4))
        let composer = self.makeComposer()

        // when
        let content = composer.monthGridContent(
            events: [event], component: component, firstWeekDay: .sunday, excludedEventIds: []
        )

        // then
        let grid = self.grid(of: content)
        #expect(grid?.weeks.count == component.weeks.count)
        #expect(grid?.weeks.map { $0.row.id } == component.weeks.map { WeekRowModel($0, month: component.month).id })
        let firstWeekEventIds = grid?.weeks.first?.eventStacks.flatMap { $0 }.map { $0.eventId }
        #expect(firstWeekEventIds == [event.eventId])
    }

    @Test func monthGridContent_ordersWeekDaysByFirstWeekDay() {
        // given
        let component = self.component(startingDays: [3])
        let composer = self.makeComposer()

        // when
        let content = composer.monthGridContent(
            events: [], component: component, firstWeekDay: .monday, excludedEventIds: []
        )

        // then
        let grid = self.grid(of: content)
        #expect(grid?.weekDays.first?.identifier == "moday")
    }

    @Test func monthGridContent_carriesExcludedEventIds() {
        // given
        let component = self.component(startingDays: [3])
        let composer = self.makeComposer()

        // when
        let content = composer.monthGridContent(
            events: [], component: component, firstWeekDay: .sunday, excludedEventIds: ["e1"]
        )

        // then
        let grid = self.grid(of: content)
        #expect(grid?.excludedEventIds == ["e1"])
    }
}


// MARK: - removingExcluded: list

extension ShareImageContentComposerTests {

    private func listLine(_ id: String, isExcluded: Bool) -> ShareImageListLine {
        return ShareImageListLine(
            eventId: id, cellViewModel: TodoEventCellViewModel(id, name: id), isExcluded: isExcluded
        )
    }

    @Test func removingExcluded_dropsExcludedLinesFromList() {
        // given
        let section = ShareImageListSection(
            dayStart: 0, dayHeaderText: nil,
            lines: [self.listLine("e1", isExcluded: true), self.listLine("e2", isExcluded: false)]
        )
        let composer = self.makeComposer()

        // when
        let result = composer.removingExcluded(.list([section]))

        // then
        let sections = self.sections(of: result)
        #expect(sections?.first?.lines.map { $0.eventId } == ["e2"])
    }

    @Test func removingExcluded_dropsSectionWhenAllLinesExcluded() {
        // given
        let allExcludedSection = ShareImageListSection(
            dayStart: 0, dayHeaderText: nil, lines: [self.listLine("e1", isExcluded: true)]
        )
        let remainingSection = ShareImageListSection(
            dayStart: 1, dayHeaderText: nil, lines: [self.listLine("e2", isExcluded: false)]
        )
        let composer = self.makeComposer()

        // when
        let result = composer.removingExcluded(.list([allExcludedSection, remainingSection]))

        // then
        let sections = self.sections(of: result)
        #expect(sections?.count == 1)
        #expect(sections?.first?.dayStart == 1)
    }
}


// MARK: - removingExcluded: monthGrid

extension ShareImageContentComposerTests {

    private func eventOnWeek(_ id: String, days: ClosedRange<Int>) -> EventOnWeek {
        let dayIdentifiers = days.map { "2026-8-\($0)" }
        let todo = TodoCalendarEvent(TodoEvent(uuid: id, name: id), in: self.timeZone)
        return EventOnWeek(0..<1, [], days, dayIdentifiers, todo)
    }

    @Test func removingExcluded_dropsExcludedEventsFromMonthStacks() {
        // given
        let row = WeekRowModel("week-1", [])
        let week = ShareImageMonthWeek(
            row: row,
            eventStacks: [[self.eventOnWeek("e1", days: 1...2), self.eventOnWeek("e2", days: 3...4)]]
        )
        let gridModel = ShareImageMonthGrid(weekDays: [], weeks: [week], excludedEventIds: ["e1"])
        let composer = self.makeComposer()

        // when
        let result = composer.removingExcluded(.monthGrid(gridModel))

        // then
        let grid = self.grid(of: result)
        let remainingIds = grid?.weeks.first?.eventStacks.flatMap { $0 }.map { $0.eventId }
        #expect(remainingIds == ["e2"])
    }

    @Test func removingExcluded_clearsExcludedIdsOnMonthGrid() {
        // given
        let row = WeekRowModel("week-1", [])
        let week = ShareImageMonthWeek(row: row, eventStacks: [[self.eventOnWeek("e1", days: 1...2)]])
        let gridModel = ShareImageMonthGrid(weekDays: [], weeks: [week], excludedEventIds: ["e1"])
        let composer = self.makeComposer()

        // when
        let result = composer.removingExcluded(.monthGrid(gridModel))

        // then
        let grid = self.grid(of: result)
        #expect(grid?.excludedEventIds.isEmpty == true)
    }
}
