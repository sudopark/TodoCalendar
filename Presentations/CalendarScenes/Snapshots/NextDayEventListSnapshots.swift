//
//  NextDayEventListSnapshots.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/7/26.
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
import CalendarPresentation


final class NextDayEventListSnapshots: XCTestCase {

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
        appearance.showHoliday = true
        appearance.showLunarCalendarDate = true
        return appearance
    }

    @MainActor
    func test_nextDayEventList_withEvents() {
        captureSnapshotPair(named: "nextDayEventList_withEvents", layout: .fixed(width: 393, height: 360)) { theme in
            self.makeNextDayView(self.makeAppearance(theme), cells: self.makeNextDayCells())
        }
    }

    @MainActor
    func test_nextDayEventList_empty() {
        captureSnapshotPair(named: "nextDayEventList_empty", layout: .fixed(width: 393, height: 160)) { theme in
            self.makeNextDayView(self.makeAppearance(theme), cells: [], holidayName: nil)
        }
    }

    @MainActor
    func test_nextDayEventList_stackedUnderDayEventList() {
        captureSnapshotPair(named: "nextDayEventList_stacked", layout: .fixed(width: 393, height: 980)) { theme in
            let appearance = self.makeAppearance(theme)
            return VStack(spacing: 0) {
                self.makeDayEventListView(appearance)
                self.makeNextDayView(appearance, cells: self.makeNextDayCells())
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(appearance.colorSet.bg0.asColor)
        }
    }

    @MainActor
    private func makeNextDayView(
        _ appearance: ViewAppearance,
        cells: [any EventCellViewModel],
        holidayName: String? = "다음날 공휴일"
    ) -> some View {
        let dayModel = SelectedDayModel(dateText: "2026년 7월 13일(월)", lunarDateText: "🌕 5월 29일")
            |> \.holidayName .~ holidayName
        let viewModel = DummyNextDayEventListViewModel(dayModel: dayModel, cellViewModels: cells)
        let state = NextDayEventListViewState()
        state.bind(viewModel, appearance)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        return NextDayEventListView()
            .environment(state)
            .environment(PendingCompleteTodoState())
            .environment(NextDayEventListViewEventHandler())
            .environment(appearance)
    }

    @MainActor
    private func makeDayEventListView(_ appearance: ViewAppearance) -> some View {
        let dayModel = SelectedDayModel(dateText: "2026년 7월 12일(일)", lunarDateText: "🌕 5월 28일")
        let cells: [any EventCellViewModel] = [
            ScheduleEventCellViewModel("today-schedule", name: "today schedule")
                |> \.periodText .~ .singleText(.init(text: "8:30", pmOram: "AM"))
        ]
        let state = DayEventListViewState()
        state.bind(FakeDayEventListViewModel(dayModel: dayModel, cellModels: cells), appearance)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        return DayEventListView()
            .environment(state)
            .environment(PendingCompleteTodoState())
            .environment(DayEventListViewEventHandler())
            .environment(appearance)
    }

    private func makeNextDayCells() -> [any EventCellViewModel] {
        let holiday = Holiday(uuid: "holiday", dateString: "2026-07-13", name: "다음날 공휴일")
        let holidayCells: [any EventCellViewModel] = HolidayCalendarEvent(holiday, in: TimeZone(abbreviation: "KST")!)
            .map { [HolidayEventCellViewModel($0)] } ?? []
        let cells: [any EventCellViewModel] = [
            ScheduleEventCellViewModel("overnight", name: "schedule from yesterday")
                |> \.periodText .~ .doubleText(
                    .init(text: "~"),
                    .init(text: "2:00", pmOram: "AM")
                )
                |> \.periodDescription .~ "Jul 12 20:00 ~ Jul 13 02:00(6hours)",
            ScheduleEventCellViewModel("meeting", name: "next day meeting")
                |> \.periodText .~ .singleText(.init(text: "10:00", pmOram: "AM")),
            TodoEventCellViewModel("todo", name: "next day todo")
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo"),
                    .init(text: "6:00", pmOram: "PM")
                )
        ]
        return holidayCells + cells
    }
}

