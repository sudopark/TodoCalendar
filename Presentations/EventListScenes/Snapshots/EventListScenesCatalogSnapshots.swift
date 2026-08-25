//
//  EventListScenesCatalogSnapshots.swift
//  EventListScenes
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Prelude
import Optics
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import EventListScenes


final class EventListScenesCatalogSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    @MainActor
    func test_doneTodos() {
        captureSnapshotPair(
            named: "doneTodos", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = DoneTodoEventListViewState()

            let recent: TimeInterval = 1_773_282_600    // 2026-03-12 09:30 KST
            let lastMonth: TimeInterval = 1_770_690_600 // 2026-02-10 09:30 KST
            let lastYear: TimeInterval = 1_752_452_000  // 2025-07-14 KST

            let recentNames = ["catalog.todo::water_plants".catalogLocalized(), "catalog.todo::reply_landlord".catalogLocalized(), "catalog.todo::book_flight".catalogLocalized()]
            let lastMonthNames = ["catalog.todo::renew_passport".catalogLocalized(), "catalog.todo::send_invoice".catalogLocalized()]
            let lastYearNames = ["catalog.todo::cancel_subscription".catalogLocalized(), "catalog.todo::return_books".catalogLocalized()]

            let recentEvents = recentNames.enumerated().map { idx, name in
                DoneTodoEvent(
                    uuid: "done-recent-\(idx)",
                    name: name,
                    originEventId: "origin-recent-\(idx)",
                    doneTime: Date(timeIntervalSince1970: recent - TimeInterval(idx * 3600))
                )
                |> \.eventTime .~ .period((recent - 3600)..<recent)
            }
            let lastMonthEvents = lastMonthNames.enumerated().map { idx, name in
                DoneTodoEvent(
                    uuid: "done-month-\(idx)",
                    name: name,
                    originEventId: "origin-month-\(idx)",
                    doneTime: Date(timeIntervalSince1970: lastMonth - TimeInterval(idx * 3600))
                )
                |> \.eventTime .~ .at(lastMonth)
            }
            let lastYearEvents = lastYearNames.enumerated().map { idx, name in
                DoneTodoEvent(
                    uuid: "done-year-\(idx)",
                    name: name,
                    originEventId: "origin-year-\(idx)",
                    doneTime: Date(timeIntervalSince1970: lastYear - TimeInterval(idx * 3600))
                )
            }

            state.sections = DoneTodoListSectionModel.builder(
                TimeZone(identifier: "Asia/Seoul")!, true
            ).build(recentEvents + lastMonthEvents + lastYearEvents)

            return DoneTodoEventListView()
                .environment(state)
                .environment(DoneTodoEventListViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
