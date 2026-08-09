//
//  CalendarScenesSnapshots.swift
//  CalendarScenes
//
//  Created by sudo.park on 7/12/26.
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


final class CalendarScenesSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let appearance = ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
        appearance.updateEventColorMap(by: [
            DefaultEventTag.default("#ff00ff"),
            DefaultEventTag.holiday("#ff0000")
        ])
        return appearance
    }

    // MARK: - Month/MonthView (rowHeight: small — eventDotsView 분기)

    @MainActor
    func test_month_smallRowHeight() {
        captureSnapshotPair(named: "month_smallRowHeight", layout: .fixed(width: 393, height: 350)) { theme in
            let viewModel = DummyMonthViewModel()
            let state = MonthViewState()
            state.bind(viewModel)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            let appearance = self.makeAppearance(theme)
            appearance.rowHeightOnCalendar = .small

            return MonthView()
                .environment(state)
                .environment(MonthViewEventHandler())
                .environment(appearance)
                .onAppear {
                    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                }
        }
    }

    // MARK: - Month/MonthView (rowHeight: medium — eventStackView·eventLineView·eventMoreViews 분기)

    @MainActor
    func test_month_mediumRowHeight() {
        captureSnapshotPair(named: "month_mediumRowHeight", layout: .fixed(width: 393, height: 500)) { theme in
            let viewModel = DummyMonthViewModel()
            let state = MonthViewState()
            state.bind(viewModel)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            let appearance = self.makeAppearance(theme)
            appearance.rowHeightOnCalendar = .medium

            return MonthView()
                .environment(state)
                .environment(MonthViewEventHandler())
                .environment(appearance)
                .onAppear {
                    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                }
        }
    }

    // MARK: - DayEventList/DayEventListView

    @MainActor
    func test_dayEventList() {
        captureSnapshotPair(named: "dayEventList", layout: .fixed(width: 393, height: 780)) { theme in
            let cells = self.makeDummyCells()
            let dayModel = SelectedDayModel(dateText: "2026년 7월 12일(일)", lunarDateText: "5월 28일")
                |> \.holidayName .~ "테스트 공휴일"

            let viewModel = FakeDayEventListViewModel(
                dayModel: dayModel,
                foremostModel: cells.first,
                uncompletedModels: self.makeDummyUncompleteds(),
                cellModels: cells
            )
            let appearance = self.makeAppearance(theme)
            appearance.showHoliday = true
            appearance.showLunarCalendarDate = true

            let state = DayEventListViewState()
            state.bind(viewModel, appearance)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return DayEventListView()
                .environment(state)
                .environment(PendingCompleteTodoState())
                .environment(DayEventListViewEventHandler())
                .environment(appearance)
        }
    }

    // AI 진입 버튼이 confirm 대기 중 원형 → 카운트다운 캡슐로 확장되는 케이스.
    @MainActor
    func test_dayEventList_aiConfirmCountdown() {
        captureSnapshotPair(named: "dayEventList_aiConfirmCountdown", layout: .fixed(width: 393, height: 780)) { theme in
            let cells = self.makeDummyCells()
            let dayModel = SelectedDayModel(dateText: "2026년 7월 12일(일)", lunarDateText: "5월 28일")
                |> \.holidayName .~ "테스트 공휴일"

            let viewModel = FakeDayEventListViewModel(
                dayModel: dayModel,
                foremostModel: cells.first,
                uncompletedModels: self.makeDummyUncompleteds(),
                cellModels: cells,
                aiAgentState: .confirm(
                    command: "삭제",
                    message: nil,
                    action: AIConfirmCommandAction(),
                    expireTime: Date().addingTimeInterval(4 * 60 + 30)
                )
            )
            let appearance = self.makeAppearance(theme)
            appearance.showHoliday = true
            appearance.showLunarCalendarDate = true

            let state = DayEventListViewState()
            state.bind(viewModel, appearance)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return DayEventListView()
                .environment(state)
                .environment(PendingCompleteTodoState())
                .environment(DayEventListViewEventHandler())
                .environment(appearance)
        }
    }

    private func makeDummyCells() -> [any EventCellViewModel] {
        let currentTodoCells: [TodoEventCellViewModel] = [
            .init("current-todo1", name: "current todo 1")
                |> \.periodText .~ .singleText(.init(text: "Todo")),
            .init("current-todo2", name: "current todo 2")
                |> \.periodText .~ .singleText(.init(text: "Todo"))
        ]
        let scheduleCells: [ScheduleEventCellViewModel] = [
            .init("sc1", name: "schedule with at time")
                |> \.periodText .~ .singleText(.init(text: "8:30", pmOram: "AM")),
            .init("sc4", name: "schedule with in today")
                |> \.periodText .~ .doubleText(
                    .init(text: "9:30", pmOram: "AM"),
                    .init(text: "8:30", pmOram: "PM")
                )
                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)"
        ]
        return currentTodoCells + scheduleCells
    }

    private func makeDummyUncompleteds() -> [TodoEventCellViewModel] {
        return [
            .init("uncompleted-todo1", name: "uncompleted - todo1")
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo"),
                    .init(text: "10:30", pmOram: "AM")
                )
        ]
    }
}


// MARK: - Test Doubles

/// DayEventListViewState의 필드가 fileprivate라 state를 직접 채울 수 없어
/// production의 bind(viewModel:appearance:) 경로로 상태를 주입하기 위한 최소 스텁.
private final class FakeDayEventListViewModel: DayEventListViewModel, @unchecked Sendable {

    private let dayModel: SelectedDayModel
    private let foremostModel: (any EventCellViewModel)?
    private let uncompletedModels: [TodoEventCellViewModel]
    private let cellModels: [any EventCellViewModel]
    private let stubAIAgentState: AIAgentState

    init(
        dayModel: SelectedDayModel,
        foremostModel: (any EventCellViewModel)?,
        uncompletedModels: [TodoEventCellViewModel],
        cellModels: [any EventCellViewModel],
        aiAgentState: AIAgentState = .idle
    ) {
        self.dayModel = dayModel
        self.foremostModel = foremostModel
        self.uncompletedModels = uncompletedModels
        self.cellModels = cellModels
        self.stubAIAgentState = aiAgentState
    }

    // 스냅샷 카탈로그는 AI 상태 화면까지 캡처해야 하므로 항상 노출
    var isAIAgentEnabled: Bool { true }

    var foremostEventModel: AnyPublisher<(any EventCellViewModel)?, Never> {
        Just(self.foremostModel).eraseToAnyPublisher()
    }
    var uncompletedTodoEventModels: AnyPublisher<[TodoEventCellViewModel], Never> {
        Just(self.uncompletedModels).eraseToAnyPublisher()
    }
    var selectedDay: AnyPublisher<SelectedDayModel, Never> {
        Just(self.dayModel).eraseToAnyPublisher()
    }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> {
        Just(self.cellModels).eraseToAnyPublisher()
    }
    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> {
        Just(.idle).eraseToAnyPublisher()
    }
    var aiAgentState: AnyPublisher<AIAgentState, Never> {
        Just(self.stubAIAgentState).eraseToAnyPublisher()
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
