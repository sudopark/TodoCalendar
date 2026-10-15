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
import Extensions
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


// MARK: - App Store 스샷용 화면

extension WidgetScenesCatalogSnapshots {

    @MainActor
    func test_storeWidgetStyleEdit() {
        let appearance = self.makeAppearance(.light)

        captureSnapshot(
            named: "storeWidgetStyleEdit-light",
            theme: .light,
            layout: .fullScreen,
            snapshotDirectory: catalogSnapshotDirectory()
        ) {
            WidgetStyleEditView(variants: [.todaySummarySmall], setting: .init())
                .environment(self.storeStyleEditState())
                .environment(WidgetStyleEditViewEventHandler())
                .environment(appearance)
                .overlay(alignment: .top) {
                    self.storeNavigationBarView(appearance)
                }
        }
    }

    /// 호스트 앱 없는 러너는 iOS 26 유리 내비게이션 바 제목을 흰색으로 그려서 앱과 같은 바를 덮어 그린다
    @MainActor
    private func storeNavigationBarView(_ appearance: ViewAppearance) -> some View {
        let textColor = appearance.colorSet.text0.asColor
        return ZStack {
            appearance.colorSet.bg1.asColor

            HStack(spacing: Metric.Spacing.xsmall) {
                Image(systemName: "chevron.backward")
                    .font(appearance.fontSet.size(17, weight: .semibold).asFont)
                Text(R.String.commonBack)
                    .font(appearance.fontSet.size(17).asFont)
                Spacer()
            }
            .foregroundStyle(textColor)
            .padding(.leading, spacing: .xlarge)

            Text("widget.style.edit::title".localized())
                .font(appearance.fontSet.size(17, weight: .semibold).asFont)
                .foregroundStyle(textColor)
        }
        .frame(height: 64)
    }

    @MainActor
    private func storeStyleEditState() -> WidgetStyleEditViewState {
        let variant = WidgetVariant.todaySummarySmall
        var withoutHoliday = TodayStyleSetting.initial
        withoutHoliday.showHolidayName = false
        var countsOnly = TodayStyleSetting.initial
        countsOnly.showTimeZone = false
        countsOnly.showMonthYear = false
        let styles = [
            WidgetStyle(id: .init(variant: variant, style: .default), name: nil, setting: TodayStyleSetting.initial),
            WidgetStyle(
                id: .init(variant: variant, style: .custom(id: "c1")),
                name: "catalog.tag::work".catalogLocalized(),
                setting: withoutHoliday,
                background: .custom(hex: "#1F3A5F")
            ),
            WidgetStyle(
                id: .init(variant: variant, style: .custom(id: "c2")),
                name: "catalog.tag::family".catalogLocalized(),
                setting: countsOnly,
                background: .custom(hex: "#F6D6DE")
            )
        ]
        let selected = styles[1]
        let state = WidgetStyleEditViewState()
        state.styles = styles.map { style in
            .init(
                styleId: style.id, name: style.displayName,
                hasUnsavedChange: false, setting: style.setting,
                background: style.background, photo: style.photo
            )
        }
        state.selectedStyleId = selected.id
        state.editingName = selected.name ?? ""
        state.selectedSetting = selected.setting
        state.selectedBackground = selected.background
        return state
    }
}
