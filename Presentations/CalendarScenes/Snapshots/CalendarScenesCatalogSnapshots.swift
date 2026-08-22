//
//  CalendarScenesCatalogSnapshots.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import CalendarScenes


final class CalendarScenesCatalogSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let appearance = ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
        appearance.updateEventColorMap(by: [
            DefaultEventTag.default("#088CDA"),
            DefaultEventTag.holiday("#D6236A")
        ])
        appearance.rowHeightOnCalendar = .medium
        appearance.showHoliday = true
        appearance.accnetDayPolicy = [.sunday: true, .saturday: true, .holiday: true]
        return appearance
    }

    /// ViewModel 요구하는 CalenarPaperContainerView 라 프로덕션 배치를 재현.
    @MainActor
    func test_calendar() {
        captureSnapshotPair(
            named: "calendar", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let appearance = self.makeAppearance(theme)

            let monthState = MonthViewState()
            monthState.bind(CatalogMonthViewModel())
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            let dayListState = DayEventListViewState()
            dayListState.bind(CatalogDayEventListViewModel(), appearance)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return ScrollView {
                VStack(spacing: 0) {
                    MonthView()
                        .environment(monthState)
                        .environment(MonthViewEventHandler())
                        .onAppear {
                            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                        }
                    DayEventListView()
                        .environment(dayListState)
                        .environment(PendingCompleteTodoState())
                        .environment(DayEventListViewEventHandler())
                }
            }
            .background(appearance.colorSet.bg0.asColor)
            .environment(appearance)
        }
    }
}


// MARK: - Test Doubles

/// 2026년 3월 — 1일이 일요일이라 앞 빈칸 없이 5주로 떨어진다.
private final class CatalogMonthViewModel: MonthViewModel, @unchecked Sendable {

    private let selectedDay = CurrentValueSubject<String?, Never>("2026-3-12")

    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        return Just([
            .init(symbol: "SUN", "SUN", isSunday: true),
            .init(symbol: "MON", "MON"),
            .init(symbol: "TUE", "TUE"),
            .init(symbol: "WED", "WED"),
            .init(symbol: "THU", "THU"),
            .init(symbol: "FRI", "FRI"),
            .init(symbol: "SAT", "SAT", isSaturday: true)
        ])
        .eraseToAnyPublisher()
    }

    var weekModels: AnyPublisher<[WeekRowModel], Never> {
        let marchDays: [DayCellViewModel] = (1...31).map { day in
            return DayCellViewModel(
                year: 2026, month: 3, day: day,
                isNotCurrentMonth: false,
                accentDay: self.accentDay(ofMarch: day)
            )
        }
        let aprilDays: [DayCellViewModel] = (1...4).map { day in
            return DayCellViewModel(
                year: 2026, month: 4, day: day,
                isNotCurrentMonth: true,
                accentDay: day == 4 ? .saturday : nil
            )
        }
        let allDays = marchDays + aprilDays
        let models = allDays.enumerated().reduce(into: [WeekRowModel]()) { acc, pair in
            let weekIndex = pair.offset / 7
            if pair.offset % 7 == 0 {
                acc.append(WeekRowModel("week:\(weekIndex)", [pair.element]))
            } else {
                acc[acc.count-1] = WeekRowModel(acc.last!.id, acc.last!.days + [pair.element])
            }
        }
        return Just(models).eraseToAnyPublisher()
    }

    private func accentDay(ofMarch day: Int) -> AccentDays? {
        if day == 1 { return .holiday }
        switch (day - 1) % 7 {
        case 0: return .sunday
        case 6: return .saturday
        default: return nil
        }
    }

    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never> {
        return Just([[], [], [], [], [], [], []]).eraseToAnyPublisher()
    }

    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        let lines: [[EventOnWeek]]
        switch weekId {
        case "week:0":
            lines = [
                [self.event("holiday", "Independence Movement Day", days: [1], seq: 1...1, ids: ["2026-3-1"])],
                [self.event("kickoff", "Project kickoff", days: [3, 4], seq: 3...4, ids: ["2026-3-3", "2026-3-4"])],
                [self.event("dentist", "Dentist", days: [5], seq: 5...5, ids: ["2026-3-5"], hasPeriod: false)]
            ]
        case "week:1":
            lines = [
                [self.event("trip", "Jeju trip", days: [2, 3, 4], seq: 2...4, ids: ["2026-3-9", "2026-3-10", "2026-3-11"])],
                [self.event("review", "Design review", days: [5], seq: 5...5, ids: ["2026-3-12"], hasPeriod: false)],
                [self.event("dinner", "Dinner with Sara", days: [6], seq: 6...6, ids: ["2026-3-13"], hasPeriod: false)]
            ]
        case "week:2":
            lines = [
                [self.event("sprint", "Sprint planning", days: [2], seq: 2...2, ids: ["2026-3-16"], hasPeriod: false)],
                [self.event("workshop", "Team workshop", days: [5, 6], seq: 5...6, ids: ["2026-3-19", "2026-3-20"])]
            ]
        case "week:3":
            lines = [
                [self.event("release", "Release day", days: [3], seq: 3...3, ids: ["2026-3-24"], hasPeriod: false)]
            ]
        default:
            lines = []
        }
        return Just(.init(linesStack: lines, shouldMarkEventDays: !lines.isEmpty))
            .eraseToAnyPublisher()
    }

    private func event(
        _ id: String, _ name: String,
        days: [Int], seq: ClosedRange<Int>, ids: [String],
        hasPeriod: Bool = true
    ) -> EventOnWeek {
        return EventOnWeek(
            0..<1, days, seq, ids,
            CatalogCalendarEvent(id, name, hasPeriod: hasPeriod, isHolidayTag: id == "holiday")
        )
    }

    var currentSelectDayIdentifier: AnyPublisher<String, Never> {
        return self.selectedDay.compactMap { $0 }.eraseToAnyPublisher()
    }

    var todayIdentifier: AnyPublisher<String, Never> {
        Just("2026-3-12").eraseToAnyPublisher()
    }

    func attachListener(_ listener: any MonthSceneListener) { }
    func select(_ day: DayCellViewModel) { }
    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel) { }
    func selectDay(_ day: CalendarDay) { }
    func clearDaySelection() { }
    func updateMonthIfNeed(_ newMonth: CalendarMonth) { }
}

private struct CatalogCalendarEvent: CalendarEvent {
    var eventId: String
    var name: String
    var eventTime: EventTime?
    var eventTimeOnCalendar: EventTimeOnCalendar?
    var eventTagId: EventTagId
    var isRepeating: Bool = false
    var isForemost: Bool = false
    var locationText: String?

    init(_ id: String, _ name: String, hasPeriod: Bool = true, isHolidayTag: Bool = false) {
        self.eventId = id
        self.name = name
        self.eventTagId = isHolidayTag ? .holiday : .default
        if hasPeriod {
            self.eventTimeOnCalendar = .init(.period(0..<1), timeZone: TimeZone.autoupdatingCurrent)
        }
    }
}

/// DayEventListViewState 의 필드가 fileprivate 라 bind(viewModel:appearance:) 경로로만 채울 수 있다.
private final class CatalogDayEventListViewModel: DayEventListViewModel, @unchecked Sendable {

    private let foremost = TodoEventCellViewModel("foremost", name: "Submit the tax return")
        |> \.periodText .~ .singleText(.init(text: "Todo"))

    private let uncompleteds: [TodoEventCellViewModel] = [
        TodoEventCellViewModel("uncompleted", name: "Reply to the landlord")
            |> \.periodText .~ .doubleText(.init(text: "Todo"), .init(text: "10:30", pmOram: "AM"))
    ]

    private let cells: [any EventCellViewModel] = {
        let todos: [TodoEventCellViewModel] = [
            TodoEventCellViewModel("todo1", name: "Water the plants")
                |> \.periodText .~ .singleText(.init(text: "Todo")),
            TodoEventCellViewModel("todo2", name: "Book the flight")
                |> \.periodText .~ .singleText(.init(text: "Todo"))
        ]
        let schedules: [ScheduleEventCellViewModel] = [
            ScheduleEventCellViewModel("sc1", name: "Design review")
                |> \.periodText .~ .singleText(.init(text: "9:30", pmOram: "AM")),
            ScheduleEventCellViewModel("sc2", name: "Lunch with Sara")
                |> \.periodText .~ .doubleText(
                    .init(text: "12:00", pmOram: "PM"),
                    .init(text: "1:00", pmOram: "PM")
                )
                |> \.periodDescription .~ "Mar 12 12:00 ~ Mar 12 13:00 (1 hour)",
            ScheduleEventCellViewModel("sc3", name: "Jeju trip")
                |> \.periodText .~ .doubleText(
                    .init(text: "Mar 9"),
                    .init(text: "Mar 11")
                )
                |> \.periodDescription .~ "Mar 9 ~ Mar 11 (3 days)"
        ]
        return todos + schedules
    }()

    var foremostEventModel: AnyPublisher<(any EventCellViewModel)?, Never> {
        Just(self.foremost).eraseToAnyPublisher()
    }
    var uncompletedTodoEventModels: AnyPublisher<[TodoEventCellViewModel], Never> {
        Just(self.uncompleteds).eraseToAnyPublisher()
    }
    var selectedDay: AnyPublisher<SelectedDayModel, Never> {
        Just(SelectedDayModel(dateText: "Thursday, March 12, 2026", lunarDateText: "")).eraseToAnyPublisher()
    }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> {
        Just(self.cells).eraseToAnyPublisher()
    }
    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> {
        Just(.idle).eraseToAnyPublisher()
    }
    var aiAgentState: AnyPublisher<AIAgentState, Never> {
        Just(.idle).eraseToAnyPublisher()
    }
    var recognizingText: AnyPublisher<String, Never> {
        Just("").eraseToAnyPublisher()
    }
    var voiceLevel: AnyPublisher<Float, Never> {
        Just(0).eraseToAnyPublisher()
    }

    func selectedDayChanaged(_ newDay: CurrentSelectDayModel, and eventThatDay: [any CalendarEvent]) { }
    func addNewTodoQuickly(withName: String) { }
    func makeTodoEvent(with givenName: String) { }
    func makeEvent() { }
    func makeEventByTemplate() { }
    func showDoneTodoList() { }
    func showSharePreview() { }
    func refreshUncompletedTodoEvents() { }
    func enterVoiceInput() { }
    func finishVoiceInput() { }
    func enterKeyboardInput() { }
    func enterImageInput() { }
    func stopAIAgentInput() { }
    func submitAIAgent(_ text: String) { }
    func handleAIEntryButtonTap() { }
    func showAIGuide() { }
    func attachListener(_ listener: any DayEventListSceneListener) { }
}
