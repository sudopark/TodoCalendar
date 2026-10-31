//
//  SettingSceneCatalogSnapshots.swift
//  SettingScene
//
//  Created by sudo.park on 7/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Combine
import Prelude
import Optics
import CommonPresentation
import SnapshotTestHelpKit

@testable import SettingScene
import AccountDomainInterface
import AccountDomainTesting
import CalendarDomainInterface
import CalendarDomainTesting
import EventDomainInterface
import EventDomainTesting
import ExternalCalendarDomainInterface
import ExternalCalendarDomainTesting
import SettingDomainInterface
import SettingDomainTesting


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

    @MainActor
    func test_colorThemeSelect() {
        captureSnapshotPair(
            named: "colorThemeSelect", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = ColorThemeSelectViewState()
            state.bind(FakeColorThemeSelectViewModel())
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return ColorThemeSelectView()
                .environment(state)
                .environment(ColorThemeSelectViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_colorThemeEdit() {
        captureSnapshotPair(
            named: "colorThemeEdit", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = ColorThemeEditViewState()
            state.bind(FakeColorThemeEditViewModel())
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return ColorThemeEditView()
                .environment(state)
                .environment(ColorThemeEditViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}


// MARK: - Test Doubles

private enum Constant {
    static let forestSeeds = CustomColorThemeSeeds(background: "#F1F5EF", accent: "#2E7D32", form: .filled)
    static let duskSeeds = CustomColorThemeSeeds(background: "#2B2438", accent: "#E5A04D", form: .filled)
}

private final class FakeColorThemeSelectViewModel: ColorThemeSelectViewModel, @unchecked Sendable {

    var sampleModel: AnyPublisher<CalendarAppearanceModel, Never> {
        Just(.init(.sunday)).eraseToAnyPublisher()
    }

    var colorThemeModels: AnyPublisher<[BuiltInColorThemeModel], Never> {
        Just([
            .init(.systemTheme) |> \.isSelected .~ true,
            .init(.defaultLight),
            .init(.defaultDark),
            .init(.appTheme(.tomato))
        ]).eraseToAnyPublisher()
    }

    var customColorThemeModels: AnyPublisher<[CustomColorThemeModel], Never> {
        Just([
            .init(self.makeCustomTheme(
                uuid: "c1", name: "catalog.colorTheme::forest".catalogLocalized(), seeds: Constant.forestSeeds
            )),
            .init(self.makeCustomTheme(
                uuid: "c2", name: "catalog.colorTheme::dusk".catalogLocalized(), seeds: Constant.duskSeeds
            ))
        ]).eraseToAnyPublisher()
    }

    private func makeCustomTheme(uuid: String, name: String, seeds: CustomColorThemeSeeds) -> CustomColorTheme {
        return CustomColorTheme(
            uuid: uuid, name: name, schemaVersion: 1,
            seeds: seeds, colors: [:], createdAt: 0, updatedAt: 0
        )
    }

    func prepare() { }
    func selectTheme(_ model: any ColorThemeModel) { }
    func createCustomTheme() { }
    func editCustomTheme(_ model: CustomColorThemeModel) { }
    func close() { }
}

private final class FakeColorThemeEditViewModel: ColorThemeEditViewModel, @unchecked Sendable {

    var initialName: String? { "catalog.colorTheme::forest".catalogLocalized() }
    var isDeletable: Bool { true }

    var sampleModel: AnyPublisher<CalendarAppearanceModel, Never> {
        Just(.init(.sunday)).eraseToAnyPublisher()
    }

    var seeds: AnyPublisher<CustomColorThemeSeeds, Never> {
        Just(Constant.forestSeeds).eraseToAnyPublisher()
    }

    var previewColorSet: AnyPublisher<ColorThemeDefinition, Never> {
        let forest = CustomColorTheme(
            uuid: "c1", name: "catalog.colorTheme::forest".catalogLocalized(), schemaVersion: 1,
            seeds: Constant.forestSeeds, colors: [:], createdAt: 0, updatedAt: 0
        )
        return Just(forest).compactMap { $0.definition() }.eraseToAnyPublisher()
    }

    var isSavable: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    var isProcessing: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    func enterName(_ name: String) { }
    func selectBackground(hex: String) { }
    func selectAccent(hex: String) { }
    func selectForm(_ form: CustomColorThemeForm) { }
    func toggleSeed(_ slot: ColorThemeEditSeedSlot, isOn: Bool) { }
    func selectSeed(_ slot: ColorThemeEditSeedSlot, hex: String) { }
    func save() { }
    func delete() { }
    func close() { }
}


// MARK: - App Store 스샷용 화면

extension SettingSceneCatalogSnapshots {

    private var storeLineupThemeKeys: [AppThemeColorSetKey] {
        return [.indigo, .amethyst, .ruby, .wine]
    }

    @MainActor
    func test_storeThemeLineup() {
        self.storeLineupThemeKeys.forEach { key in
            let appearance = self.makeStoreLineupAppearance(key)
            captureSnapshot(
                named: "storeThemeLineup-\(key.rawValue)",
                theme: appearance.colorSet.isLightTheme ? .light : .dark,
                layout: .fullScreen,
                snapshotDirectory: catalogSnapshotDirectory()
            ) {
                self.makeStoreSettingItemListView(appearance)
                    .tint(appearance.colorSet.accent.asColor)
            }
        }
    }

    @MainActor
    private func makeStoreLineupAppearance(_ key: AppThemeColorSetKey) -> ViewAppearance {
        let colorSetKey = ColorSetKeys.appTheme(key)
        let isLightTheme = colorSetKey.convert(isSystemDarkTheme: false).isLightTheme
        let calendar = CalendarAppearanceSettings(colorSetKey: colorSetKey, fontSetKey: .systemDefault)
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: !isLightTheme)
    }

    @MainActor
    private func makeStoreSettingItemListView(_ appearance: ViewAppearance) -> some View {
        let state = SettingItemListViewState()
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
                SettingItemModel(.openWeb),
                SettingItemModel(.feedback),
                SettingItemModel(.help)
            ]
        )
        let appInfoSection = AppInfoSectionModel(
            headerText: "setting.section.app::name".localized(),
            version: "v3.1.0",
            isUpdateAvailable: false,
            items: [
                SettingItemModel(.shareApp),
                SettingItemModel(.addReview),
                SettingItemModel(.openSourceLicense)
            ]
        )
        state.sections = [baseSection, supportSection, appInfoSection]

        return SettingItemListView()
            .environment(state)
            .environment(SettingItemListViewEventHandler())
            .environment(appearance)
    }
}


// MARK: - 마케팅 소재

extension SettingSceneCatalogSnapshots {

    /// 호스트 앱 없이 xctest 로 돌아 앱 에셋 카탈로그의 구글 아이콘을 못 찾는다 — 같은 원본을 행의 아이콘 자리에 얹는다.
    private enum GoogleIconOverlay {
        static let size: CGFloat = 25
        static let leading: CGFloat = 32
        static let rowCenters: [CGFloat] = [468.5, 527.5]
    }

    private var googleCalendarIcon: UIImage? {
        let filePath = "\(#filePath)"
        guard let range = filePath.range(of: "/Presentations/") else { return nil }
        let root = filePath[..<range.lowerBound]
        return UIImage(
            contentsOfFile: "\(root)/TodoCalendarApp/Resources/Assets.xcassets/google_calendar_icon.imageset/google_calendar_icon.png"
        )
    }

    @MainActor
    private func makeMarketingAppearance() -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(colorSetKey: .defaultLight, fontSetKey: .systemDefault)
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#9CC3F5")
        let appearance = ViewAppearance(
            setting: AppearanceSettings(calendar: calendar, defaultTagColor: tag), isSystemDarkTheme: false
        )
        appearance.updateEventColorMap(by: [DefaultEventTag.default("#9CC3F5"), DefaultEventTag.holiday("#D6236A")])
        return appearance
    }

    @MainActor
    func test_marketingGoogleConnect() {
        captureSnapshot(
            named: "marketingGoogleConnect",
            theme: .light,
            layout: .fullScreen,
            snapshotDirectory: catalogSnapshotDirectory()
        ) {
            let state = EventSettingViewState()
            state.tagModel = .init(DefaultEventTag.default("#9CC3F5"))
            state.periodModel = .init(EventSettings.DefaultNewEventPeriod.hour1)
            state.selectedEventNotificationTimeText = DefaultTimeOptionModel(option: .before(seconds: 600)).text
            state.selectedAllDayEventNotificationTimeText = DefaultTimeOptionModel(option: .allDay9AM).text
            state.externalCalendarServiceModels = [
                ExternalCalanserServiceModel(
                    GoogleCalendarService(scopes: [.readonly]),
                    accountId: "team@example.com"
                ),
                ExternalCalanserServiceModel(
                    GoogleCalendarService(scopes: [.readonly]),
                    accountId: nil
                )
            ].compactMap { $0 }

            return EventSettingView()
                .environment(state)
                .environment(EventSettingViewEventHandler())
                .environment(self.makeMarketingAppearance())
                .overlay(alignment: .topLeading) {
                    ForEach(GoogleIconOverlay.rowCenters, id: \.self) { centerY in
                        self.googleCalendarIcon.map { icon in
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFill()
                                .frame(width: GoogleIconOverlay.size, height: GoogleIconOverlay.size)
                                .offset(x: GoogleIconOverlay.leading, y: centerY - GoogleIconOverlay.size / 2)
                        }
                    }
                }
        }
    }
}
