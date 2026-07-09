//
//  SettingSceneCatalogSnapshots.swift
//  SettingScene
//
//  Created by sudo.park on 7/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import SettingScene


final class SettingSceneCatalogSnapshots: XCTestCase {

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
    func test_settingItemList() {
        captureSnapshotPair(
            named: "settingItemList", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = SettingItemListViewState()
            let eventHandlers = SettingItemListViewEventHandler()
            let baseSection = SettingSectionModel(
                headerText: nil,
                items: [
                    SettingItemModel(.appearance),
                    SettingItemModel(.editEvent),
                    SettingItemModel(.holidaySetting),
                    AccountSettingItemModel(nil)
                ]
            )
            let supportSection = SettingSectionModel(
                headerText: "setting.section.support::name".localized(),
                items: [
                    SettingItemModel(.feedback),
                    SettingItemModel(.help)
                ]
            )
            let appInfoSection = AppInfoSectionModel(
                headerText: "setting.section.app::name".localized(),
                version: "v2.9.2",
                isUpdateAvailable: true,
                items: [
                    SettingItemModel(.shareApp),
                    SettingItemModel(.addReview),
                    SettingItemModel(.sourceCode)
                ]
            )
            let suggestSection = SettingSectionModel(
                headerText: "setting.section.suggest::name".localized(),
                items: [SuggestAppItemModel.readmind()]
            )
            state.sections = [baseSection, supportSection, appInfoSection, suggestSection]

            return SettingItemListView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_countrySelect() {
        captureSnapshotPair(
            named: "countrySelect", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = CountrySelectViewState()
            let eventHandlers = CountrySelectViewEventHandler()

            state.countries = (0..<20).map {
                return HolidaySupportCountry(regionCode: "region:\($0)", code: "code:\($0)", name: "name:\($0)")
            }
            state.selectedCountryCode = "code:3"
            state.isSavable = true
            state.isSaving = true

            return CountrySelectView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }
}
