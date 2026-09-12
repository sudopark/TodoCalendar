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
        _ item: WidgetGalleryItem, selecting variant: WidgetVariant? = nil
    ) -> WidgetGalleryDetailViewState {
        let state = WidgetGalleryDetailViewState()
        state.itemName = item.name
        state.variants = item.variants
        state.selectedVariantId = (variant ?? item.variants.first)?.id
        return state
    }
    
    @MainActor
    private func listState() -> WidgetGalleryViewState {
        let state = WidgetGalleryViewState()
        state.items = WidgetGalleryItem.allCases
        return state
    }
    
    // MARK: - 1뎁스 종류 목록
    
    @MainActor
    func test_widgetGalleryList() {
        captureSnapshotPair(named: "widgetGalleryList", layout: .fullScreen) { theme in
            WidgetGalleryView()
                .environment(self.listState())
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
    
    @MainActor
    func test_widgetGalleryDetail_customizableVariant() {
        captureSnapshotPair(named: "widgetGalleryDetail-customizable", layout: .fullScreen) { theme in
            WidgetGalleryDetailView()
                .environment(self.detailState(.todaySummary))
                .environment(WidgetGalleryDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    // MARK: - 3뎁스 스타일 편집
    
    @MainActor
    private func styleEditState(_ turnedOffItems: Set<TodayStyleItem> = []) -> WidgetStyleEditViewState {
        let styleId = WidgetStyleId(variant: .todaySummarySmall, style: .default)
        let setting = TodayStyleItem.allCases.reduce(into: TodayStyleSetting()) { acc, item in
            acc[keyPath: item.settingKeyPath] = turnedOffItems.contains(item) ? false : nil
        }
        let state = WidgetStyleEditViewState()
        state.styles = [
            .init(styleId: styleId, name: styleId.style.name, setting: setting)
        ]
        state.selectedStyleId = styleId
        state.items = TodayStyleItem.allCases.map {
            .init(item: $0, isOn: turnedOffItems.contains($0) == false)
        }
        return state
    }
    
    @MainActor
    func test_widgetStyleEdit_allItemsOn() {
        captureSnapshotPair(named: "widgetStyleEdit-allOn", layout: .fullScreen) { theme in
            WidgetStyleEditView(variant: .todaySummarySmall, setting: .init())
                .environment(self.styleEditState())
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_countItemsAllOff() {
        captureSnapshotPair(named: "widgetStyleEdit-countsOff", layout: .fullScreen) { theme in
            WidgetStyleEditView(variant: .todaySummarySmall, setting: .init())
                .environment(
                    self.styleEditState([.showTotalCount, .showTodoCount, .showScheduleCount])
                )
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_someItemsOff() {
        captureSnapshotPair(named: "widgetStyleEdit-someOff", layout: .fullScreen) { theme in
            WidgetStyleEditView(variant: .todaySummarySmall, setting: .init())
                .environment(self.styleEditState([.showTimeZone, .showTotalCount]))
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
