//
//  CommonComponentSnapshots.swift
//  CommonPresentation
//
//  Created by sudo.park on 7/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import SnapshotTestHelpKit

@testable import CommonPresentation


final class CommonComponentSnapshots: XCTestCase {

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
    func test_bottomConfirmButton() {
        captureSnapshotPair(named: "bottomConfirmButton", layout: .fixed(width: 400, height: 120)) { theme in
            BottomConfirmButton(title: "Confirm")
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_eventTagColorView() {
        captureSnapshotPair(named: "eventTagColorView", layout: .component) { theme in
            EventTagColorView(EventTagId.default) { color in
                Circle().fill(color).frame(width: 24, height: 24)
            }
            .padding()
            .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_sheetHeader() {
        captureSnapshotPair(named: "sheetHeader", layout: .fixed(width: 400, height: 80)) { theme in
            SheetHeaderView(title: "Sheet Title")
                .padding(.horizontal)
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_confirmButton() {
        captureSnapshotPair(named: "confirmButton", layout: .fixed(width: 400, height: 80)) { theme in
            ConfirmButton(title: "Confirm")
                .padding()
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_fullScreenLoadingView() {
        captureSnapshotPair(named: "fullScreenLoadingView", layout: .fullScreen) { theme in
            let appearance = self.makeAppearance(theme)
            return ZStack {
                appearance.colorSet.bg1.asColor.ignoresSafeArea()
                FullScreenLoadingView(isLoading: true)
            }
            .environment(appearance)
        }
    }

    @MainActor
    func test_descriptionView() {
        captureSnapshotPair(named: "descriptionView", layout: .fixed(width: 360, height: 120)) { theme in
            let appearance = self.makeAppearance(theme)
            return DescriptionView(descriptions: [
                "First tip description",
                "Second tip description with longer text to wrap"
            ])
            .padding()
            .background(appearance.colorSet.bg0.asColor)
            .environment(appearance)
        }
    }
}
