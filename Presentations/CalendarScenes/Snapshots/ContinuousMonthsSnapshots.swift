//
//  ContinuousMonthsSnapshots.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import CalendarScenes
import CalendarPresentation


final class ContinuousMonthsSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme, rowHeight: RowHeightOnCalendar) -> ViewAppearance {
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
        appearance.rowHeightOnCalendar = rowHeight
        return appearance
    }

    // 컬렉션 뷰를 감싸 찍으면 캡처 도구가 셀을 다시 구성해 이벤트가 오기 전에 찍힌다
    @MainActor
    private func capture(named name: String, rowHeight: RowHeightOnCalendar, testName: String = #function) {
        captureSnapshotPair(named: name, layout: .fixed(width: 456, height: 560), testName: testName) { theme in
            self.makeFocusedSectionsView(self.makeAppearance(theme, rowHeight: rowHeight))
        }
    }

    @MainActor
    private func makeFocusedSectionsView(_ appearance: ViewAppearance) -> some View {
        let viewModel = DummyContinuousMonthsViewModel()
        let state = ContinuousMonthsViewState()
        state.rowWidth = 456 - 16
        state.bind(viewModel)
        var sections: [ContinuousMonthSection] = []
        let subscription = viewModel.sections.sink { sections = $0 }
        subscription.cancel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let weeks = sections.dropFirst(2).flatMap { $0.weeks }

        return VStack(spacing: 0) {
            ContinuousMonthsHeaderView()
            ForEach(weeks, id: \.id) { week in
                ContinuousMonthsWeekCellView(week: week)
                    .padding([.leading, .trailing], spacing: .small)
            }
        }
        .frame(width: 456, height: 560, alignment: .top)
        .clipped()
        .background(ContinuousMonthsBackgroundView())
        .environment(state)
        .environment(ContinuousMonthsViewEventHandler())
        .environment(appearance)
        .onAppear {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
    }

    // MARK: - 포커스 2023-09 — 경계 주·포커스 밖 흐림·선택일·오늘

    @MainActor
    func test_continuousMonths_mediumRowHeight() {
        self.capture(named: "continuousMonths_mediumRowHeight", rowHeight: .medium)
    }

    @MainActor
    func test_continuousMonths_smallRowHeight() {
        self.capture(named: "continuousMonths_smallRowHeight", rowHeight: .small)
    }

    @MainActor
    func test_continuousMonths_largeRowHeight() {
        self.capture(named: "continuousMonths_largeRowHeight", rowHeight: .large)
    }
}

