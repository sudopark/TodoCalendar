//
//  WidgetGallerySnapshots.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import WidgetScenes


final class WidgetGallerySnapshots: XCTestCase {
    
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
    private func detailState(
        _ item: WidgetGalleryItem, selecting variant: WidgetGalleryVariant? = nil
    ) -> WidgetGalleryDetailViewState {
        let state = WidgetGalleryDetailViewState()
        state.itemName = item.name
        state.variants = item.variants
        state.selectedVariantId = (variant ?? item.variants.first)?.id
        return state
    }
    
    @MainActor
    private func listState(isDDayWidgetEnabled: Bool) -> WidgetGalleryViewState {
        let state = WidgetGalleryViewState()
        state.items = WidgetGalleryItem.allCases.filter {
            $0 != .dday || isDDayWidgetEnabled
        }
        return state
    }
    
    // MARK: - 1뎁스 종류 목록
    
    @MainActor
    func test_widgetGalleryList_ddayHidden() {
        captureSnapshotPair(named: "widgetGalleryList-ddayHidden", layout: .fullScreen) { theme in
            WidgetGalleryView()
                .environment(self.listState(isDDayWidgetEnabled: false))
                .environment(WidgetGalleryViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetGalleryList_ddayShown() {
        captureSnapshotPair(named: "widgetGalleryList-ddayShown", layout: .fullScreen) { theme in
            WidgetGalleryView()
                .environment(self.listState(isDDayWidgetEnabled: true))
                .environment(WidgetGalleryViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    // MARK: - 2뎁스 변형 페이저
    
    @MainActor
    func test_widgetGalleryDetail_dday() {
        captureSnapshotPair(named: "widgetGalleryDetail-dday", layout: .fullScreen) { theme in
            WidgetGalleryDetailView()
                .environment(self.detailState(.dday))
                .environment(WidgetGalleryDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetGalleryDetail_ddayLockScreen() {
        captureSnapshotPair(named: "widgetGalleryDetail-ddayLockScreen", layout: .fullScreen) { theme in
            WidgetGalleryDetailView()
                .environment(self.detailState(.dday, selecting: .ddayCircular))
                .environment(WidgetGalleryDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetGalleryDetail_weekEvents() {
        captureSnapshotPair(named: "widgetGalleryDetail-weekEvents", layout: .fullScreen) { theme in
            WidgetGalleryDetailView()
                .environment(self.detailState(.weekEvents))
                .environment(WidgetGalleryDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetGalleryDetail_singleVariant() {
        captureSnapshotPair(named: "widgetGalleryDetail-singleVariant", layout: .fullScreen) { theme in
            WidgetGalleryDetailView()
                .environment(self.detailState(.month))
                .environment(WidgetGalleryDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
