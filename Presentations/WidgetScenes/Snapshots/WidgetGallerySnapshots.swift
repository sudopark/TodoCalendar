//
//  WidgetGallerySnapshots.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Prelude
import Optics
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
    private func detailStateWithCustomStyles() -> WidgetGalleryDetailViewState {
        let variant = WidgetVariant.todaySummarySmall
        let styles: [any WidgetStyleSetting] = [
            TodayStyleSetting.initial,
            TodayStyleSetting.initial |> \.showMonthYear .~ false,
            TodayStyleSetting.initial |> \.showTodoCount .~ false |> \.showScheduleCount .~ false
        ]
        let state = self.detailState(.todaySummary)
        state.previewStyles = WidgetPreviewStyleStack(styles: styles)
            .map { [variant.id: $0] } ?? [:]
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
    
    @MainActor
    func test_widgetGalleryDetail_withCustomStyles() {
        captureSnapshotPair(named: "widgetGalleryDetail-customStyles", layout: .fullScreen) { theme in
            WidgetGalleryDetailView()
                .environment(self.detailStateWithCustomStyles())
                .environment(WidgetGalleryDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    // MARK: - 3뎁스 스타일 편집
    
    @MainActor
    private func styleEditState(_ turnedOffItems: Set<TodayStyleItem> = []) -> WidgetStyleEditViewState {
        let styleId = WidgetStyleId(variant: .todaySummarySmall, style: .default)
        let setting = TodayStyleItem.allCases.reduce(into: TodayStyleSetting.initial) { acc, item in
            acc[keyPath: item.settingKeyPath] = turnedOffItems.contains(item) == false
        }
        let style = WidgetStyle(id: styleId, name: nil, setting: setting)
        let state = WidgetStyleEditViewState()
        state.styles = [
            .init(
                styleId: style.id, name: style.displayName,
                hasUnsavedChange: false, setting: style.setting
            )
        ]
        state.selectedStyleId = styleId
        state.selectedSetting = setting
        return state
    }
    
    @MainActor
    private func styleEditStateWithCustoms(
        hasUnsavedChanges: Bool = false
    ) -> WidgetStyleEditViewState {
        let variant = WidgetVariant.todaySummarySmall
        let styles = [
            WidgetStyle(
                id: .init(variant: variant, style: .default),
                name: nil,
                setting: TodayStyleSetting.initial
            ),
            WidgetStyle(
                id: .init(variant: variant, style: .custom(id: "c1")),
                name: "Night",
                setting: TodayStyleSetting.initial |> \.showHolidayName .~ false
            ),
            WidgetStyle(
                id: .init(variant: variant, style: .custom(id: "c2")),
                name: nil,
                setting: TodayStyleSetting.initial |> \.showTimeZone .~ false
            )
        ]
        let selected = styles[1]
        let state = WidgetStyleEditViewState()
        state.styles = styles.enumerated().map { index, style in
            .init(
                styleId: style.id, name: style.displayName,
                hasUnsavedChange: index == 1 && hasUnsavedChanges, setting: style.setting
            )
        }
        state.hasUnsavedChange = hasUnsavedChanges
        state.selectedStyleId = selected.id
        state.editingName = selected.name ?? ""
        state.selectedSetting = selected.setting
        return state
    }
    
    @MainActor
    func test_widgetStyleEdit_monthYearOff() {
        captureSnapshotPair(named: "widgetStyleEdit-monthYearOff", layout: .fullScreen) { theme in
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(self.styleEditState([.showMonthYear]))
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_dayOnly() {
        captureSnapshotPair(named: "widgetStyleEdit-dayOnly", layout: .fullScreen) { theme in
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(
                    self.styleEditState([
                        .showMonthYear, .showTotalCount, .showTodoCount, .showScheduleCount
                    ])
                )
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_withCustomStyles() {
        captureSnapshotPair(named: "widgetStyleEdit-customStyles", layout: .fullScreen) { theme in
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(self.styleEditStateWithCustoms())
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_withUnsavedChanges() {
        captureSnapshotPair(named: "widgetStyleEdit-unsaved", layout: .fullScreen) { theme in
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(self.styleEditStateWithCustoms(hasUnsavedChanges: true))
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_defaultSelected_hasNoNameRow() {
        captureSnapshotPair(named: "widgetStyleEdit-defaultSelected", layout: .fullScreen) { theme in
            let state = self.styleEditStateWithCustoms()
            state.selectedStyleId = .init(variant: .todaySummarySmall, style: .default)
            return WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(state)
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_allItemsOn() {
        captureSnapshotPair(named: "widgetStyleEdit-allOn", layout: .fullScreen) { theme in
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(self.styleEditState())
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
    
    @MainActor
    func test_widgetStyleEdit_countItemsAllOff() {
        captureSnapshotPair(named: "widgetStyleEdit-countsOff", layout: .fullScreen) { theme in
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
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
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(self.styleEditState([.showTimeZone, .showTotalCount]))
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
