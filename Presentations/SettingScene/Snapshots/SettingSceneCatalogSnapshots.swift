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
import Extensions
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
                    SettingItemModel(.billingPlan),
                    AccountSettingItemModel(AccountInfo("some"))
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
                    SettingItemModel(.openSourceLicense)
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
            state.isSaving = false

            return CountrySelectView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }
}


// MARK: - 가이드 페이지용 화면 (#903)

extension SettingSceneCatalogSnapshots {

    @MainActor
    func test_eventTypeList() {
        captureSnapshotPair(
            named: "eventTypeList", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = EventTagListViewState()
            let tags: [(String, String)] = [
                ("catalog.tag::work".catalogLocalized(), "#088CDA"),
                ("catalog.tag::family".catalogLocalized(), "#F9316D"),
                ("catalog.tag::health".catalogLocalized(), "#3CB371"),
                ("catalog.tag::study".catalogLocalized(), "#FFA02E")
            ]
            let customTags = tags.enumerated().map { idx, pair in
                CustomEventTag(uuid: "tag:\(idx)", name: pair.0, colorHex: pair.1)
            }
            state.cellviewModels = customTags.map { BaseCalendarEventTagCellViewModel($0) }
            state.externalCalendarTagSections = [
                .init(
                    serviceId: GoogleCalendarService.id,
                    serviceTitle: "Google Calendar",
                    cellViewModels: [],
                    offIds: []
                )
            ]
            let appearance = self.makeAppearance(theme)
            appearance.updateEventColorMap(by: customTags)

            return EventTagListView(isRootNavigation: true)
                .environment(appearance)
                .environment(state)
                .environment(EventTagListEventHandlers())
        }
    }

    @MainActor
    func test_appearanceSetting() {
        captureSnapshotPair(
            named: "appearanceSetting", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let calendar = CalendarAppearanceSettings(
                colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
                fontSetKey: .systemDefault
            )
            let appearance = self.makeAppearance(theme)
            appearance.accnetDayPolicy = [.sunday: true, .saturday: true, .holiday: true]
            appearance.showUnderLineOnEventDay = true

            return AppearanceSettingContainerView(
                calendar,
                viewAppearance: appearance,
                calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler(),
                eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler(),
                eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler(),
                appearanceSettingEventHandler: AppearanceSettingViewEventHandler()
            )
            .eventHandler(\.calendarSectionStateBinding) {
                $0.calendarModel = .init(.monday)
                $0.accentDays = [.holiday: true, .sunday: true]
                $0.selectedWeekDay = .monday
                $0.showUnderLine = true
            }
            .eventHandler(\.eventOnCalendarSectionStateBinding) {
                $0.additionalFontSizeModel = .init(3)
                $0.isShowEventTagColor = true
            }
        }
    }
}


// MARK: - App Store 스샷용 화면 (#996)

extension SettingSceneCatalogSnapshots {

    /// 캘린더 스샷(CalendarScenesCatalogSnapshots.test_storeCalendar)과 색이 어긋나면
    /// 같은 라인업의 두 장이 앞뒤가 안 맞는다 — 색 값은 test_eventTypeList 픽스처와 같이 간다.
    private var storeEventTags: [CustomEventTag] {
        let tags: [(String, String)] = [
            ("catalog.tag::work", "#088CDA"),
            ("catalog.tag::family", "#F9316D"),
            ("catalog.tag::health", "#3CB371"),
            ("catalog.tag::study", "#FFA02E")
        ]
        return tags.map { key, colorHex in
            CustomEventTag(uuid: key, name: key.catalogLocalized(), colorHex: colorHex)
        }
    }

    private var storeExternalCalendarSections: [ExternalCalendarEventTagListSectionModel] {
        let services: [(String, String)] = [
            (GoogleCalendarService.id, "event_setting::external_calendar::google::serviceName"),
            (AppleCalendarService.id, "event_setting::external_calendar::apple::serviceName")
        ]
        return services.map { serviceId, titleKey in
            ExternalCalendarEventTagListSectionModel(
                serviceId: serviceId,
                serviceTitle: titleKey.localized(),
                cellViewModels: [],
                offIds: []
            )
        }
    }

    @MainActor
    func test_storeEventTypeList() {
        captureSnapshotPair(
            named: "storeEventTypeList", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = EventTagListViewState()
            let customTags = self.storeEventTags
            state.cellviewModels = customTags.map { BaseCalendarEventTagCellViewModel($0) }
            state.externalCalendarTagSections = self.storeExternalCalendarSections

            let appearance = self.makeAppearance(theme)
            appearance.updateEventColorMap(by: customTags)

            return EventTagListView(isRootNavigation: true)
                .environment(appearance)
                .environment(state)
                .environment(EventTagListEventHandlers())
        }
    }
}
