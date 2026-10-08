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
import TestDoubles

@testable import CalendarScenes
import CalendarPresentation


final class CalendarScenesSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        return self.makeAppearance(
            theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            isSystemDarkTheme: theme.isSystemDarkTheme
        )
    }

    @MainActor
    private func makeLineupAppearance(_ key: AppThemeColorSetKey) -> ViewAppearance {
        let colorSetKey = ColorSetKeys.appTheme(key)
        let isLightTheme = colorSetKey.convert(isSystemDarkTheme: false).isLightTheme
        return self.makeAppearance(colorSetKey, isSystemDarkTheme: !isLightTheme)
    }

    @MainActor
    private func makeAppearance(_ key: ColorSetKeys, isSystemDarkTheme: Bool) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: key,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let appearance = ViewAppearance(setting: setting, isSystemDarkTheme: isSystemDarkTheme)
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
            let appearance = self.makeAppearance(theme)
            appearance.rowHeightOnCalendar = .small

            let viewModel = DummyMonthViewModel()
            let state = MonthViewState()
            state.bind(viewModel, appearance)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return MonthView()
                .environment(state)
                .environment(MonthViewEventHandler())
                .environment(appearance)
                .onAppear {
                    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                }
        }
    }

    // MARK: - Month/MonthView (접힘 — 선택 주 한 줄 + eventDotsView, rowHeight 설정 무관)

    @MainActor
    func test_month_collapsed() {
        captureSnapshotPair(named: "month_collapsed", layout: .fixed(width: 393, height: 100)) { theme in
            let appearance = self.makeAppearance(theme)
            appearance.rowHeightOnCalendar = .medium

            let viewModel = DummyMonthViewModel()
            let state = MonthViewState()
            state.bind(viewModel, appearance)
            viewModel.selectDay(.init(2023, 9, 13))
            viewModel.updateMonthCollapsed(true)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

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
            self.makeMonthMediumRowHeightView(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_month_mediumRowHeight_lineupThemes() {
        AppThemeColorSetKey.allCases.forEach { key in
            let appearance = self.makeLineupAppearance(key)
            captureSnapshot(
                named: "month_mediumRowHeight-\(key.rawValue)",
                theme: appearance.colorSet.isLightTheme ? .light : .dark,
                layout: .fixed(width: 393, height: 500)
            ) {
                self.makeMonthMediumRowHeightView(appearance)
                    .tint(appearance.colorSet.accent.asColor)
            }
        }
    }

    @MainActor
    private func makeMonthMediumRowHeightView(_ appearance: ViewAppearance) -> some View {
        appearance.rowHeightOnCalendar = .medium

        let viewModel = DummyMonthViewModel()
        let state = MonthViewState()
        state.bind(viewModel, appearance)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        return MonthView()
            .environment(state)
            .environment(MonthViewEventHandler())
            .environment(appearance)
            .onAppear {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            }
    }

    // MARK: - DayEventList/DayEventListView

    @MainActor
    func test_dayEventList() {
        captureSnapshotPair(named: "dayEventList", layout: .fixed(width: 393, height: 780)) { theme in
            self.makeDayEventListView(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_dayEventList_lineupThemes() {
        AppThemeColorSetKey.snapshotRepresentatives.forEach { key in
            let appearance = self.makeLineupAppearance(key)
            captureSnapshot(
                named: "dayEventList-\(key.rawValue)",
                theme: appearance.colorSet.isLightTheme ? .light : .dark,
                layout: .fixed(width: 393, height: 780)
            ) {
                self.makeDayEventListView(appearance)
                    .tint(appearance.colorSet.accent.asColor)
            }
        }
    }

    @MainActor
    private func makeDayEventListView(_ appearance: ViewAppearance) -> some View {
        let cells = self.makeDummyCells()
        let dayModel = SelectedDayModel(dateText: "2026년 7월 12일(일)", lunarDateText: "5월 28일")
            |> \.holidayName .~ "테스트 공휴일"

        let viewModel = FakeDayEventListViewModel(
            dayModel: dayModel,
            foremostModel: cells.first,
            uncompletedModels: self.makeDummyUncompleteds(),
            cellModels: cells
        )
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
