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
        let styles: [WidgetStyle] = [
            self.todayStyle(.default, TodayStyleSetting.initial),
            self.todayStyle(
                .custom(id: "c1"),
                TodayStyleSetting.initial |> \.showMonthYear .~ false,
                background: .custom(hex: "#101820")
            ),
            self.todayStyle(
                .custom(id: "c2"),
                TodayStyleSetting.initial |> \.showTodoCount .~ false |> \.showScheduleCount .~ false
            )
        ]
        let state = self.detailState(.todaySummary)
        state.previewStyles = WidgetPreviewStyleStack(styles: styles)
            .map { [variant.id: $0] } ?? [:]
        return state
    }
    
    private func todayStyle(
        _ style: WidgetStyleId.Style,
        _ setting: TodayStyleSetting,
        background: WidgetAppearanceSettings.Background? = nil
    ) -> WidgetStyle {
        return .init(
            id: .init(variant: .todaySummarySmall, style: style),
            name: nil, setting: setting, background: background
        )
    }
    
    @MainActor
    private func listState() -> WidgetGalleryViewState {
        let state = WidgetGalleryViewState()
        state.items = WidgetGalleryItem.allCases
        state.defaultStyles = [
            WidgetVariant.todaySummarySmall.id: self.todayStyle(
                .default, TodayStyleSetting.initial, background: .custom(hex: "#101820")
            )
        ]
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
                hasUnsavedChange: false, setting: style.setting,
                background: style.background
            )
        ]
        state.selectedStyleId = styleId
        state.selectedSetting = setting
        state.selectedBackground = style.background
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
                setting: TodayStyleSetting.initial |> \.showHolidayName .~ false,
                background: .custom(hex: "#101820")
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
                hasUnsavedChange: index == 1 && hasUnsavedChanges, setting: style.setting,
                background: style.background
            )
        }
        state.hasUnsavedChange = hasUnsavedChanges
        state.selectedStyleId = selected.id
        state.editingName = selected.name ?? ""
        state.selectedSetting = selected.setting
        state.selectedBackground = selected.background
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
            state.selectedBackground = nil
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


// MARK: - 합성 위젯 스타일 편집 — 토글 OFF

extension WidgetGallerySnapshots {

    private func allOff<Item: WidgetStyleItem>(_ item: Item.Type) -> Item.Setting {
        return Item.allCases.reduce(Item.Setting.initial) { acc, item in
            acc |> item.settingKeyPath .~ false
        }
    }

    @MainActor
    private func composedEditState(
        _ variant: WidgetVariant, setting: any WidgetStyleSetting
    ) -> WidgetStyleEditViewState {
        let style = WidgetStyle(
            id: .init(variant: variant, style: .default), name: nil,
            setting: setting, background: .custom(hex: "#1F3A5F")
        )
        let state = WidgetStyleEditViewState()
        state.styles = [
            .init(
                styleId: style.id, name: style.displayName,
                hasUnsavedChange: false, setting: style.setting,
                background: style.background
            )
        ]
        state.selectedStyleId = style.id
        state.selectedSetting = style.setting
        state.selectedBackground = style.background
        return state
    }

    @MainActor
    private func captureComposedEdit(
        _ name: String,
        _ variant: WidgetVariant,
        setting: any WidgetStyleSetting,
        testName: String = #function
    ) {
        captureSnapshotPair(named: name, layout: .fullScreen, testName: testName) { theme in
            WidgetStyleEditView(variants: [variant], setting: .init())
                .environment(self.composedEditState(variant, setting: setting))
                .environment(WidgetStyleEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_widgetStyleEdit_doubleMonth_allTogglesOff() {
        self.captureComposedEdit(
            "widgetStyleEdit-doubleMonth-allOff", .doubleMonthMedium,
            setting: DoubleMonthStyleSetting.initial |> \.month .~ self.allOff(MonthStyleItem.self)
        )
    }

    @MainActor
    func test_widgetStyleEdit_eventAndMonth_allTogglesOff() {
        self.captureComposedEdit(
            "widgetStyleEdit-eventAndMonth-allOff", .eventAndMonthMedium,
            setting: EventAndMonthStyleSetting.initial |> \.month .~ self.allOff(MonthStyleItem.self)
        )
    }

    @MainActor
    func test_widgetStyleEdit_eventAndForemost_allTogglesOff() {
        self.captureComposedEdit(
            "widgetStyleEdit-eventAndForemost-allOff", .eventAndForemostMedium,
            setting: EventAndForemostStyleSetting.initial |> \.foremost .~ self.allOff(ForemostStyleItem.self)
        )
    }

    @MainActor
    func test_widgetStyleEdit_todayAndMonth_allTogglesOff() {
        self.captureComposedEdit(
            "widgetStyleEdit-todayAndMonth-allOff", .todayAndMonthMedium,
            setting: TodayAndMonthStyleSetting.initial
                |> \.today .~ self.allOff(TodayStyleItem.self)
                |> \.month .~ self.allOff(MonthStyleItem.self)
        )
    }
}
