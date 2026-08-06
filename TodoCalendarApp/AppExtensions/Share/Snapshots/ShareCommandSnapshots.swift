//
//  ShareCommandSnapshots.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import SnapshotTestHelpKit

@testable import TodoCalendarAppShare


final class ShareCommandSnapshots: XCTestCase {

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

    @MainActor
    func test_editing() {
        captureSnapshotPair(named: "editing", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = false
                state.sharedText = "9월 10일 오후 3시 강남역에서 미팅"
            }
        }
    }
}
