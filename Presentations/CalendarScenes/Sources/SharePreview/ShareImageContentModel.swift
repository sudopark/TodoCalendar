//
//  ShareImageContentModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


// MARK: - SharePreviewFormat

/// Picker의 `.tag(_:)`가 Hashable을 요구한다
enum SharePreviewFormat: Hashable, Sendable {
    case text
    case image
}


// MARK: - ShareImageListLine

struct ShareImageListLine: Identifiable, Sendable {
    let eventId: String
    let cellViewModel: any EventCellViewModel
    var isExcluded: Bool
    var id: String { self.eventId }
}

extension ShareImageListLine: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.eventId == rhs.eventId
            && lhs.cellViewModel.customCompareKey == rhs.cellViewModel.customCompareKey
            && lhs.isExcluded == rhs.isExcluded
    }
}


// MARK: - ShareImageListSection

struct ShareImageListSection: Equatable, Sendable, Identifiable {
    /// nil = 날짜에 매이지 않는 할일 섹션
    let dayStart: TimeInterval?
    let dayHeaderText: String?
    let lines: [ShareImageListLine]
    var id: String { self.dayStart.map { "\($0)" } ?? "undated" }
}


// MARK: - Month 컴포넌트 Sendable 보강

// 타입 홈 파일 밖 소급 conformance라 @unchecked가 강제된다. 저장 프로퍼티는 전부 Sendable임을 확인함.
extension WeekRowModel: @unchecked Sendable {}
extension DayCellViewModel: @unchecked Sendable {}
extension EventOnWeek: @unchecked Sendable {}
extension WeekDayModel: @unchecked Sendable {}


// MARK: - ShareImageMonthGrid

struct ShareImageMonthWeek: Equatable, Sendable, Identifiable {
    let row: WeekRowModel
    let eventStacks: [[EventOnWeek]]
    var id: String { self.row.id }
}

struct ShareImageMonthGrid: Equatable, Sendable {
    let weekDays: [WeekDayModel]
    let weeks: [ShareImageMonthWeek]
    let excludedEventIds: Set<String>
}


// MARK: - ShareImageContentModel

enum ShareImageContentModel: Equatable, Sendable {
    case list([ShareImageListSection])
    case monthGrid(ShareImageMonthGrid)
}


// MARK: - ShareImageContentComposer

struct ShareImageContentComposer {

    let timeZone: TimeZone
    let is24hourForm: Bool

    private var calendar: Calendar {
        return Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
    }

    func listContent(
        events: [any CalendarEvent],
        currentTodos: [TodoCalendarEvent],
        range: Range<TimeInterval>,
        excludedEventIds: Set<String>
    ) -> ShareImageContentModel {
        let undatedLines = currentTodos.sortedByCreateTime().compactMap {
            self.line(currentTodo: $0, in: range, excludedEventIds: excludedEventIds)
        }
        let overlappingEvents = events.filter { $0.eventTimeOnCalendar?.clamped(to: range) != nil }
        let datedLines = overlappingEvents.sortedByEventTime().compactMap { event in
            self.dayStart(for: event, in: range).flatMap { dayStart in
                self.line(event: event, dayStart: dayStart, excludedEventIds: excludedEventIds)
                    .map { (dayStart, $0) }
            }
        }

        let groups = Dictionary(grouping: datedLines, by: { $0.0 })
        let sortedDayStarts = groups.keys.sorted()
        let isMultiDay = sortedDayStarts.count > 1

        let undatedSection = undatedLines.isEmpty ? nil : ShareImageListSection(
            dayStart: nil, dayHeaderText: nil, lines: undatedLines
        )
        let daySections = sortedDayStarts.map { dayStart in
            ShareImageListSection(
                dayStart: dayStart,
                dayHeaderText: isMultiDay ? self.dayHeaderText(for: dayStart) : nil,
                lines: (groups[dayStart] ?? []).map { $0.1 }
            )
        }
        return .list([undatedSection].compactMap { $0 } + daySections)
    }

    func monthGridContent(
        events: [any CalendarEvent],
        component: CalendarComponent,
        firstWeekDay: DayOfWeeks,
        excludedEventIds: Set<String>
    ) -> ShareImageContentModel {
        let weekDays = WeekDayModel.allModels(of: firstWeekDay)
        let stackBuilder = WeekEventStackBuilder(self.timeZone)
        let weeks = component.weeks.map { week in
            ShareImageMonthWeek(
                row: WeekRowModel(week, month: component.month),
                eventStacks: stackBuilder.build(week, events: events).eventStacks
            )
        }
        return .monthGrid(
            ShareImageMonthGrid(weekDays: weekDays, weeks: weeks, excludedEventIds: excludedEventIds)
        )
    }

    func removingExcluded(_ content: ShareImageContentModel) -> ShareImageContentModel {
        switch content {
        case .list(let sections):
            let filtered = sections.compactMap { section -> ShareImageListSection? in
                let lines = section.lines.filter { !$0.isExcluded }
                guard !lines.isEmpty else { return nil }
                return ShareImageListSection(dayStart: section.dayStart, dayHeaderText: section.dayHeaderText, lines: lines)
            }
            return .list(filtered)

        case .monthGrid(let grid):
            let weeks = grid.weeks.map { week -> ShareImageMonthWeek in
                let stacks = week.eventStacks
                    .map { row in row.filter { !grid.excludedEventIds.contains($0.eventId) } }
                    .filter { !$0.isEmpty }
                return ShareImageMonthWeek(row: week.row, eventStacks: stacks)
            }
            return .monthGrid(
                ShareImageMonthGrid(weekDays: grid.weekDays, weeks: weeks, excludedEventIds: [])
            )
        }
    }
}


// MARK: - ShareImageContentComposer + pure composition

extension ShareImageContentComposer {

    private func dayStart(for event: any CalendarEvent, in range: Range<TimeInterval>) -> TimeInterval? {
        guard let anchor = event.eventTimeOnCalendar?.clamped(to: range)?.lowerBound else { return nil }
        return self.calendar.startOfDay(for: Date(timeIntervalSince1970: anchor)).timeIntervalSince1970
    }

    private func dayRange(startingAt dayStart: TimeInterval) -> Range<TimeInterval> {
        let start = Date(timeIntervalSince1970: dayStart)
        let end = self.calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return dayStart..<end.timeIntervalSince1970
    }

    private func dayHeaderText(for dayStart: TimeInterval) -> String {
        let formatter = DateFormatter() |> \.timeZone .~ self.timeZone
        formatter.dateFormat = "date_form.MMM_dd_E".localized()
        return formatter.string(from: Date(timeIntervalSince1970: dayStart))
    }

    private func line(
        event: any CalendarEvent,
        dayStart: TimeInterval,
        excludedEventIds: Set<String>
    ) -> ShareImageListLine? {
        let mapper = EventCellViewModelMapper(
            range: self.dayRange(startingAt: dayStart), timeZone: self.timeZone, is24hourForm: self.is24hourForm
        )
        guard let cellViewModel = mapper.cellViewModel(from: event) else { return nil }
        return ShareImageListLine(
            eventId: event.eventId,
            cellViewModel: cellViewModel,
            isExcluded: excludedEventIds.contains(event.eventId)
        )
    }

    private func line(
        currentTodo: TodoCalendarEvent,
        in range: Range<TimeInterval>,
        excludedEventIds: Set<String>
    ) -> ShareImageListLine? {
        guard let cellViewModel = TodoEventCellViewModel(currentTodo, in: range, self.timeZone, self.is24hourForm)
        else { return nil }
        return ShareImageListLine(
            eventId: currentTodo.eventId,
            cellViewModel: cellViewModel,
            isExcluded: excludedEventIds.contains(currentTodo.eventId)
        )
    }
}
