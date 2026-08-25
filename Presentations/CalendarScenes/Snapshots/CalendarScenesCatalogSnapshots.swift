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
import Extensions
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
        return Just(WeekDayModel.allModels()).eraseToAnyPublisher()
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
                [self.event("holiday", "catalog.event::holiday".catalogLocalized(), days: [1], seq: 1...1, ids: ["2026-3-1"])],
                [self.event("kickoff", "catalog.event::project_kickoff".catalogLocalized(), days: [3, 4], seq: 3...4, ids: ["2026-3-3", "2026-3-4"])],
                [self.event("dentist", "catalog.event::dentist".catalogLocalized(), days: [5], seq: 5...5, ids: ["2026-3-5"], hasPeriod: false)]
            ]
        case "week:1":
            lines = [
                [self.event("trip", "catalog.event::trip".catalogLocalized(), days: [2, 3, 4], seq: 2...4, ids: ["2026-3-9", "2026-3-10", "2026-3-11"])],
                [self.event("review", "catalog.event::design_review".catalogLocalized(), days: [5], seq: 5...5, ids: ["2026-3-12"], hasPeriod: false)],
                [self.event("dinner", "catalog.event::dinner".catalogLocalized(), days: [6], seq: 6...6, ids: ["2026-3-13"], hasPeriod: false)]
            ]
        case "week:2":
            lines = [
                [self.event("sprint", "catalog.event::sprint_planning".catalogLocalized(), days: [2], seq: 2...2, ids: ["2026-3-16"], hasPeriod: false)],
                [self.event("workshop", "catalog.event::team_workshop".catalogLocalized(), days: [5, 6], seq: 5...6, ids: ["2026-3-19", "2026-3-20"])]
            ]
        case "week:3":
            lines = [
                [self.event("release", "catalog.event::release_day".catalogLocalized(), days: [3], seq: 3...3, ids: ["2026-3-24"], hasPeriod: false)]
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

    private enum Constant {
        /// 2026-03-12(목) 00:00 ~ 03-13 00:00 KST
        static let todayRange: Range<TimeInterval> = 1_773_241_200..<1_773_327_600
        static let uncompletedTodoTime: TimeInterval = 1_773_279_000     // 10:30
        static let designReviewTime: TimeInterval = 1_773_275_400        // 09:30
        static let lunchPeriod: Range<TimeInterval> = 1_773_284_400..<1_773_288_000  // 12:00~13:00
        /// 03-09 ~ 03-11 종일 — upperBound 가 03-11 00:00 이라 3일로 표시된다
        static let tripPeriod: Range<TimeInterval> = 1_772_982_000..<1_773_154_800
    }

    private let timeZone = TimeZone(identifier: "Asia/Seoul")!

    private lazy var foremost: TodoEventCellViewModel = self.currentTodoCell(
        "foremost", "catalog.todo::tax_return".catalogLocalized(), isForemost: true
    )

    private lazy var uncompleteds: [TodoEventCellViewModel] = {
        let todo = TodoEvent(uuid: "uncompleted", name: "catalog.todo::reply_landlord".catalogLocalized())
            |> \.time .~ .at(Constant.uncompletedTodoTime)
        let event = TodoCalendarEvent(todo, in: self.timeZone)
        return TodoEventCellViewModel(event, in: Constant.todayRange, self.timeZone, false)
            .map { [$0] } ?? []
    }()

    private lazy var cells: [any EventCellViewModel] = {
        let todos: [TodoEventCellViewModel] = [
            self.currentTodoCell("todo1", "catalog.todo::water_plants".catalogLocalized()),
            self.currentTodoCell("todo2", "catalog.todo::book_flight".catalogLocalized())
        ]
        let schedules: [ScheduleEventCellViewModel] = [
            ScheduleEvent(uuid: "sc1", name: "catalog.event::design_review".catalogLocalized(), time: .at(Constant.designReviewTime)),
            ScheduleEvent(uuid: "sc2", name: "catalog.event::lunch".catalogLocalized(), time: .period(Constant.lunchPeriod)),
            ScheduleEvent(
                uuid: "sc3", name: "catalog.event::trip".catalogLocalized(),
                time: .allDay(Constant.tripPeriod, secondsFromGMT: TimeInterval(self.timeZone.secondsFromGMT()))
            )
        ]
        .flatMap { ScheduleCalendarEvent.events(from: $0, in: self.timeZone) }
        .compactMap {
            ScheduleEventCellViewModel($0, in: Constant.todayRange, timeZone: self.timeZone, false)
        }
        return todos + schedules
    }()

    private func currentTodoCell(
        _ id: String, _ name: String, isForemost: Bool = false
    ) -> TodoEventCellViewModel {
        return TodoEventCellViewModel(
            currentTodo: TodoCalendarEvent(
                current: TodoEvent(uuid: id, name: name), isForemost: isForemost
            )
        )
    }

    var foremostEventModel: AnyPublisher<(any EventCellViewModel)?, Never> {
        Just(self.foremost).eraseToAnyPublisher()
    }
    var uncompletedTodoEventModels: AnyPublisher<[TodoEventCellViewModel], Never> {
        Just(self.uncompleteds).eraseToAnyPublisher()
    }
    var selectedDay: AnyPublisher<SelectedDayModel, Never> {
        let currentDay = CurrentSelectDayModel(
            2026, 3, 12, weekId: "week:1", range: Constant.todayRange
        )
        return Just(SelectedDayModel(self.timeZone, currentModel: currentDay))
            .eraseToAnyPublisher()
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
