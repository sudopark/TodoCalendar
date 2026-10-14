//
//  WidgetScenesCatalogSnapshots.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import WidgetScenes


final class WidgetScenesCatalogSnapshots: XCTestCase {

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
    private func listState() -> WidgetGalleryViewState {
        let state = WidgetGalleryViewState()
        state.items = WidgetGalleryItem.allCases
        state.defaultStyles = [
            WidgetVariant.todaySummarySmall.id: WidgetStyle(
                id: .init(variant: .todaySummarySmall, style: .default),
                name: nil, setting: TodayStyleSetting.initial, background: .custom(hex: "#101820")
            )
        ]
        return state
    }

    @MainActor
    private func styleEditState() -> WidgetStyleEditViewState {
        let styleId = WidgetStyleId(variant: .todaySummarySmall, style: .default)
        let setting = TodayStyleItem.allCases.reduce(into: TodayStyleSetting.initial) { acc, item in
            acc[keyPath: item.settingKeyPath] = true
        }
        let style = WidgetStyle(id: styleId, name: nil, setting: setting)
        let state = WidgetStyleEditViewState()
        state.styles = [
            .init(
                styleId: style.id, name: style.displayName,
                hasUnsavedChange: false, setting: style.setting,
                background: style.background, photo: style.photo
            )
        ]
        state.selectedStyleId = styleId
        state.selectedSetting = setting
        state.selectedBackground = style.background
        return state
    }

    @MainActor
    func test_widgetGallery() {
        captureSnapshotPair(
            named: "widgetGallery", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            WidgetGalleryView()
                .environment(self.listState())
                .environment(WidgetGalleryViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_widgetStyleEdit() {
        captureSnapshotPair(
            named: "widgetStyleEdit", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(self.styleEditState())
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
