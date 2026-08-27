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


// MARK: - App Store 스샷용 화면 (#996)

extension CalendarScenesCatalogSnapshots {

    private var storeCalendarMonth: (year: Int, month: Int) { (2026, 3) }

    private var storeCalendarMonthDate: Date {
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(
            year: self.storeCalendarMonth.year, month: self.storeCalendarMonth.month, day: 1
        )
        return calendar.date(from: components) ?? Date()
    }

    @MainActor
    private func makeStoreAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let appearance = self.makeAppearance(theme)
        let tags: [any EventTag] = [
            DefaultEventTag.default("#088CDA"),
            DefaultEventTag.holiday("#D6236A"),
            StoreCatalogEventTag.work.customTag,
            StoreCatalogEventTag.family.customTag,
            StoreCatalogEventTag.health.customTag,
            StoreCatalogEventTag.study.customTag
        ]
        appearance.updateEventColorMap(by: tags)
        return appearance
    }

    /// 프로덕션 월 헤더는 앱 타겟 MainViewController 의 private HeaderView 라 여기서 참조할 수 없다 — 같은 메트릭으로 재현한다.
    @MainActor
    private func storeCalendarHeaderView(_ appearance: ViewAppearance) -> some View {
        let formatter = DateFormatter() |> \.dateFormat .~ "date_form.MMM".localized()
        let chevronFont: Font = .system(size: 13, weight: .semibold)
        return HStack(spacing: Metric.Spacing.small) {
            Image(systemName: "chevron.left")
                .font(chevronFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
                .frame(width: 24)

            HStack(alignment: .lastTextBaseline, spacing: Metric.Spacing.xsmall) {
                Text(formatter.string(from: self.storeCalendarMonthDate).uppercased())
                    .font(appearance.fontSet.bigMonth.asFont)
                Text(verbatim: "\(self.storeCalendarMonth.year)")
                    .font(appearance.fontSet.normal.asFont)
            }
            .foregroundStyle(appearance.colorSet.text0.asColor)

            Image(systemName: "chevron.right")
                .font(chevronFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
                .frame(width: 24)

            Spacer()

            HStack(spacing: Metric.Spacing.small) {
                ForEach(["calendar", "line.3.horizontal.decrease.circle", "gearshape"], id: \.self) { name in
                    Image(systemName: name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, spacing: .large)
        .background(appearance.colorSet.dayBackground.asColor)
    }

    @MainActor
    func test_storeCalendar() {
        captureSnapshotPair(
            named: "storeCalendar", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let appearance = self.makeStoreAppearance(theme)

            let monthState = MonthViewState()
            monthState.bind(StoreCatalogMonthViewModel())
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            let dayListState = DayEventListViewState()
            dayListState.bind(CatalogDayEventListViewModel(), appearance)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return VStack(spacing: 0) {
                self.storeCalendarHeaderView(appearance)
                ScrollView {
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
            }
            .background(appearance.colorSet.bg0.asColor)
            .environment(appearance)
        }
    }
}


// MARK: - Test Doubles

/// 2026년 3월 — 1일이 일요일이라 앞 빈칸 없이 5주로 떨어진다.
private class CatalogMonthViewModel: MonthViewModel, @unchecked Sendable {

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
        let lines = self.eventLines(at: weekId)
        return Just(.init(linesStack: lines, shouldMarkEventDays: !lines.isEmpty))
            .eraseToAnyPublisher()
    }

    fileprivate func eventLines(at weekId: String) -> [[EventOnWeek]] {
        let lines: [[EventOnWeek]]
        switch weekId {
        case "week:0":
            lines = [
                [self.event("holiday", "catalog.event::holiday".catalogLocalized(), days: [1], seq: 1...1, ids: ["2026-3-1"], tagId: .holiday)],
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
        return lines
    }

    fileprivate func event(
        _ id: String, _ name: String,
        days: [Int], seq: ClosedRange<Int>, ids: [String],
        tagId: EventTagId = .default,
        hasPeriod: Bool = true
    ) -> EventOnWeek {
        return EventOnWeek(
            0..<1, days, seq, ids,
            CatalogCalendarEvent(id, name, hasPeriod: hasPeriod, tagId: tagId)
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

    init(_ id: String, _ name: String, hasPeriod: Bool = true, tagId: EventTagId = .default) {
        self.eventId = id
        self.name = name
        self.eventTagId = tagId
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


private enum StoreCatalogEventTag: String {
    case work
    case family
    case health
    case study

    var key: String { "catalog.tag::\(self.rawValue)" }

    var tagId: EventTagId { .custom(self.key) }

    var colorHex: String {
        switch self {
        case .work: return "#088CDA"
        case .family: return "#F9316D"
        case .health: return "#3CB371"
        case .study: return "#FFA02E"
        }
    }

    var customTag: CustomEventTag {
        return CustomEventTag(uuid: self.key, name: self.key.catalogLocalized(), colorHex: self.colorHex)
    }
}

/// 3월 19일에 다섯 줄을 겹쳐 `+N` 오버플로우가 나오게 한다.
private final class StoreCatalogMonthViewModel: CatalogMonthViewModel, @unchecked Sendable {

    override fileprivate func eventLines(at weekId: String) -> [[EventOnWeek]] {
        switch weekId {
        case "week:0":
            return [
                [self.march("holiday", "holiday", days: [1], seq: 1...1, tagId: .holiday)],
                [
                    self.march("sprint-1", "sprint_planning", days: [2], seq: 2...2, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false),
                    self.march("review-1", "design_review", days: [5], seq: 5...5, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false)
                ],
                [
                    self.march("dentist-1", "dentist", days: [4], seq: 4...4, tagId: StoreCatalogEventTag.health.tagId, hasPeriod: false),
                    self.march("dinner-1", "dinner", days: [7], seq: 7...7, tagId: StoreCatalogEventTag.family.tagId, hasPeriod: false)
                ]
            ]
        case "week:1":
            return [
                [self.march("trip-1", "trip", days: [9, 10, 11], seq: 2...4, tagId: StoreCatalogEventTag.family.tagId)],
                [
                    self.march("sprint-2", "sprint_planning", days: [9], seq: 2...2, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false),
                    self.march("review-2", "design_review", days: [12], seq: 5...5, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false)
                ],
                [
                    self.march("release-1", "release_day", days: [10], seq: 3...3, hasPeriod: false),
                    self.march("lunch-1", "lunch", days: [13], seq: 6...6, tagId: StoreCatalogEventTag.family.tagId, hasPeriod: false)
                ]
            ]
        case "week:2":
            return [
                [self.march("workshop-1", "team_workshop", days: [19, 20], seq: 5...6, tagId: StoreCatalogEventTag.study.tagId)],
                [
                    self.march("sprint-3", "sprint_planning", days: [16], seq: 2...2, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false),
                    self.march("review-3", "design_review", days: [19], seq: 5...5, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false)
                ],
                [
                    self.march("lunch-2", "lunch", days: [17], seq: 3...3, tagId: StoreCatalogEventTag.family.tagId, hasPeriod: false),
                    self.march("dentist-2", "dentist", days: [19], seq: 5...5, tagId: StoreCatalogEventTag.health.tagId, hasPeriod: false)
                ],
                [
                    self.march("kickoff-1", "project_kickoff", days: [17], seq: 3...3, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false),
                    self.march("release-2", "release_day", days: [19], seq: 5...5, hasPeriod: false)
                ],
                [self.march("dinner-2", "dinner", days: [19], seq: 5...5, tagId: StoreCatalogEventTag.family.tagId, hasPeriod: false)]
            ]
        case "week:3":
            return [
                [
                    self.march("sprint-4", "sprint_planning", days: [23], seq: 2...2, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false),
                    self.march("review-4", "design_review", days: [26], seq: 5...5, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false)
                ],
                [
                    self.march("dentist-3", "dentist", days: [24], seq: 3...3, tagId: StoreCatalogEventTag.health.tagId, hasPeriod: false),
                    self.march("dinner-3", "dinner", days: [28], seq: 7...7, tagId: StoreCatalogEventTag.family.tagId, hasPeriod: false)
                ],
                [self.march("workshop-2", "team_workshop", days: [27, 28], seq: 6...7, tagId: StoreCatalogEventTag.study.tagId)]
            ]
        case "week:4":
            return [
                [
                    self.march("sprint-5", "sprint_planning", days: [30], seq: 2...2, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false),
                    self.april("review-5", "design_review", days: [2], seq: 5...5, tagId: StoreCatalogEventTag.work.tagId, hasPeriod: false)
                ],
                [self.april("trip-2", "trip", days: [3, 4], seq: 6...7, tagId: StoreCatalogEventTag.family.tagId)],
                [
                    self.march("release-3", "release_day", days: [31], seq: 3...3, hasPeriod: false),
                    self.april("lunch-3", "lunch", days: [1], seq: 4...4, tagId: StoreCatalogEventTag.family.tagId, hasPeriod: false)
                ]
            ]
        default:
            return []
        }
    }

    private func march(
        _ id: String, _ nameKey: String,
        days: [Int], seq: ClosedRange<Int>,
        tagId: EventTagId = .default, hasPeriod: Bool = true
    ) -> EventOnWeek {
        return self.dayOfMonth(id, nameKey, month: 3, days: days, seq: seq, tagId: tagId, hasPeriod: hasPeriod)
    }

    private func april(
        _ id: String, _ nameKey: String,
        days: [Int], seq: ClosedRange<Int>,
        tagId: EventTagId = .default, hasPeriod: Bool = true
    ) -> EventOnWeek {
        return self.dayOfMonth(id, nameKey, month: 4, days: days, seq: seq, tagId: tagId, hasPeriod: hasPeriod)
    }

    private func dayOfMonth(
        _ id: String, _ nameKey: String, month: Int,
        days: [Int], seq: ClosedRange<Int>,
        tagId: EventTagId, hasPeriod: Bool
    ) -> EventOnWeek {
        return self.event(
            id, "catalog.event::\(nameKey)".catalogLocalized(),
            days: days, seq: seq, ids: days.map { "2026-\(month)-\($0)" },
            tagId: tagId, hasPeriod: hasPeriod
        )
    }
}
