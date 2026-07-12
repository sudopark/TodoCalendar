//
//  EventListScenesSnapshots.swift
//  EventListScenes
//
//  Created by sudo.park on 7/12/26.
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


final class EventListScenesSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    // MARK: - DoneTodoList/DoneTodoEventListView

    // 결정성: doneTime은 서로 다른 연도의 고정 epoch(Asia/Seoul) — 실제 실행 시점(Date())과
    // 무관하게 항상 "yyyy_MM_dd" 포맷 분기로 떨어져 today/yesterday 상대 라벨을 타지 않는다.
    @MainActor
    func test_doneTodoEventList() {
        captureSnapshotPair(named: "doneTodoEventList", layout: .fullScreen) { theme in
            let state = DoneTodoEventListViewState()
            let eventHandlers = DoneTodoEventListViewEventHandler()

            let section3Time: TimeInterval = 1_667_606_400 // 2022-11-05 09:00 KST
            let section2Time: TimeInterval = 1_624_147_200 // 2021-06-20 09:00 KST
            let section1Time: TimeInterval = 1_579_046_400 // 2020-01-15 09:00 KST

            let section3Events = (0..<2).map { idx in
                DoneTodoEvent(
                    uuid: "done-3-\(idx)",
                    name: "완료한 할일 3-\(idx)",
                    originEventId: "origin-3-\(idx)",
                    doneTime: Date(timeIntervalSince1970: section3Time - TimeInterval(idx * 300))
                )
                |> \.eventTime .~ .period(
                    (section3Time - 3600)..<section3Time
                )
            }
            let section2Events = (0..<3).map { idx in
                DoneTodoEvent(
                    uuid: "done-2-\(idx)",
                    name: "완료한 할일 2-\(idx)",
                    originEventId: "origin-2-\(idx)",
                    doneTime: Date(timeIntervalSince1970: section2Time - TimeInterval(idx * 300))
                )
                |> \.eventTime .~ .at(section2Time)
            }
            let section1Events = (0..<2).map { idx in
                DoneTodoEvent(
                    uuid: "done-1-\(idx)",
                    name: "완료한 할일 1-\(idx)",
                    originEventId: "origin-1-\(idx)",
                    doneTime: Date(timeIntervalSince1970: section1Time - TimeInterval(idx * 300))
                )
            }

            let sections = DoneTodoListSectionModel.builder(
                TimeZone(identifier: "Asia/Seoul")!, true
            ).build(section3Events + section2Events + section1Events)
            state.sections = sections

            return DoneTodoEventListView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }
}
