//
//  SettingSceneSnapshots.swift
//  SettingScene
//
//  Created by sudo.park on 7/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import SettingScene


final class SettingSceneSnapshots: XCTestCase {

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
    private func makeAppearanceSettingViewAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let appearance = self.makeAppearance(theme)
        appearance.accnetDayPolicy = [
            .sunday: true, .saturday: true, .holiday: true
        ]
        appearance.showUnderLineOnEventDay = true
        return appearance
    }

    // MARK: - Setting/SettingItemListView

    @MainActor
    func test_settingItemList() {
        captureSnapshotPair(named: "settingItemList", layout: .fullScreen) { theme in
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
                    SettingItemModel(.sourceCode)
                ]
            )
            state.sections = [baseSection, supportSection, appInfoSection]

            return SettingItemListView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Setting/Appearance/TimeZone/TimeZoneSelectView

    @MainActor
    func test_timeZoneSelect() {
        captureSnapshotPair(named: "timeZoneSelect", layout: .fullScreen) { theme in
            let state = TimeZoneSelectViewState()
            let eventHandlers = TimeZoneSelectViewEventHandler()

            state.systemTimeZone = .init("Asia/Seoul", title: "시스템 설정")
                |> \.description .~ "대한민국 표준시 (GMT+9)"

            state.timeZones = [
                .init("Pacific/Midway", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midway2", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midway3", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midwa4", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midway5", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midway6", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midway7", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midway8", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
                .init("Pacific/Midway9", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)"
            ]
            state.selectedIdentifier = "Asia/Seoul"

            return TimeZoneSelectView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Setting/Appearance/Widget/WidgetAppearanceSettingView

    @MainActor
    func test_widgetAppearanceSetting() {
        captureSnapshotPair(named: "widgetAppearanceSetting", layout: .fullScreen) { theme in
            let state = WidgetAppearanceSettingViewState()
            let eventHandlers = WidgetAppearanceSettingViewEventHandler()
            state.background = .custom(hex: "#3355FF")
            state.isSystemTheme = false
            state.customBackground = UIColor.from(hex: "#3355FF")?.asColor

            return WidgetAppearanceSettingView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Event/EventSettingView

    @MainActor
    func test_eventSetting() {
        captureSnapshotPair(named: "eventSetting", layout: .fullScreen) { theme in
            let state = EventSettingViewState()
            let eventHandlers = EventSettingViewEventHandler()
            state.tagModel = .init(
                DefaultEventTag.default("#ff00ff")
            )
            state.periodModel = .init(EventSettings.DefaultNewEventPeriod.minute15)
            state.selectedEventNotificationTimeText = "so long text hahahahhahahha hahah"
            state.selectedAllDayEventNotificationTimeText = "so long text hahahahhahahha hahah"
            state.externalCalendarServiceModels = [
                ExternalCalanserServiceModel(
                    GoogleCalendarService(scopes: [.readWrite]),
                    accountId: nil
                )!
            ]
            state.eventSyncModel = .syncInProgress

            return EventSettingView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - EventTag/EventDefaultTagSelect/EventDefaultTagSelectView

    @MainActor
    func test_eventDefaultTagSelect() {
        captureSnapshotPair(named: "eventDefaultTagSelect", layout: .fullScreen) { theme in
            let state = EventDefaultTagSelectViewState()
            let eventHandlers = EventDefaultTagSelectViewEventHandler()
            state.cellViewModels = (0..<20).map {
                BaseCalendarEventTagCellViewModel(
                    CustomEventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "#ff0000")
                )
                |> \.isOn .~ ($0 % 2 == 0)
            }
            state.selectedId = .custom("id:3")

            return EventDefaultTagSelectView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Event/EventNotificationDefaultTimeOption/EventNotificationDefaultTimeOptionView

    @MainActor
    func test_eventNotificationDefaultTimeOption() {
        captureSnapshotPair(named: "eventNotificationDefaultTimeOption", layout: .fullScreen) { theme in
            let state = EventNotificationDefaultTimeOptionViewState()
            state.isNeedNotificationPermission = true
            state.options = [
                .init(option: nil),
                .init(option: .atTime),
                .init(option: .before(seconds: 60)),
                .init(option: .before(seconds: 60*3.0)),
                .init(option: .before(seconds: 60*5.0)),
                .init(option: .before(seconds: 60*10.0)),
                .init(option: .before(seconds: 60*60.0)),
                .init(option: .before(seconds: 60*60.0*2)),
                .init(option: .before(seconds: 60*60.0*3)),
                .init(option: .before(seconds: 60*60.0*24)),
                .init(option: .before(seconds: 60*60.48)),
                .init(option: .before(seconds: 60*60.24*7)),
                .init(option: .before(seconds: 60*60.24*14)),
            ]
            let eventHandlers = EventNotificationDefaultTimeOptionViewEventHandler()

            return EventNotificationDefaultTimeOptionView(isForAllDay: false)
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Event/EventDefaultMapApp/EventDefaultMapAppView

    @MainActor
    func test_eventDefaultMapApp() {
        captureSnapshotPair(named: "eventDefaultMapApp", layout: .fullScreen) { theme in
            let state = EventDefaultMapAppViewState()
            state.models = [
                .init(map: .apple),
                .init(map: .google, isSelected: true)
            ]
            let eventHandlers = EventDefaultMapAppViewEventHandler()

            return EventDefaultMapAppView()
                .environment(self.makeAppearance(theme))
                .environment(state)
                .environment(eventHandlers)
        }
    }

    // MARK: - EventTag/EventTagList/EventTagListView

    @MainActor
    func test_eventTagList() {
        captureSnapshotPair(named: "eventTagList", layout: .fullScreen) { theme in
            let state = EventTagListViewState()
            state.cellviewModels = (0..<4).map {
                let tag = CustomEventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "#ff0000")
                return BaseCalendarEventTagCellViewModel(tag)
            }
            state.externalCalendarTagSections = [
                .init(
                    serviceId: GoogleCalendarService.id,
                    serviceTitle: "Google Calendar",
                    cellViewModels: [],
                    offIds: []
                )
            ]
            let eventHandler = EventTagListEventHandlers()

            return EventTagListView(isRootNavigation: true)
                .environment(self.makeAppearance(theme))
                .environment(state)
                .environment(eventHandler)
        }
    }

    // MARK: - EventTag/EventTagDetail/EventTagDetailView

    @MainActor
    func test_eventTagDetail() {
        captureSnapshotPair(named: "eventTagDetail", layout: .fullScreen) { theme in
            let state = EventTagDetailViewState()
            let eventHandler = EventTagDetailEventHandler()
            state.bind(FakeEventTagDetailViewModel())
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return EventTagDetailView()
                .environment(self.makeAppearance(theme))
                .environment(state)
                .environment(eventHandler)
        }
    }

    // MARK: - Setting/Holiday/HolidayListView

    @MainActor
    func test_holidayList() {
        captureSnapshotPair(named: "holidayList", layout: .fullScreen) { theme in
            let state = HolidayListViewState()
            let eventHandlers = HolidayListViewEventHandler()
            state.countryName = "대한민국"
            state.holidays = (0..<15).compactMap { int in
                let holiday = Holiday(uuid: "hd", dateString: "2023-01-\(int+1)", name: "some: \(int)")
                return HolidayItemModel(holiday)
            }

            return HolidayListView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Setting/Holiday/CountrySelectView

    @MainActor
    func test_countrySelect() {
        captureSnapshotPair(named: "countrySelect", layout: .fullScreen) { theme in
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

    // MARK: - Support/Feedback/FeedbackPostView

    @MainActor
    func test_feedbackPost() {
        captureSnapshotPair(named: "feedbackPost", layout: .fullScreen) { theme in
            let state = FeedbackPostViewState()
            state.inputMessage = "앱을 쓰다가 발견한 버그를 알려드려요."
            state.inputContact = "sudo.park@kakao.com"
            state.isPostable = true
            let eventHandlers = FeedbackPostViewEventHandler()

            return FeedbackPostView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Setting/Appearance/ColorTheme/ColorThemeSelectView (covers ColorThemePreviewView)

    @MainActor
    func test_colorThemeSelect() {
        captureSnapshotPair(named: "colorThemeSelect", layout: .fullScreen) { theme in
            let state = ColorThemeSelectViewState()
            let eventHandlers = ColorThemeSelectViewEventHandler()
            state.bind(FakeColorThemeSelectViewModel())
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            return ColorThemeSelectView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Setting/Appearance/AppearanceSettingView (covers CalendarAppearancePreviewView, EventOnCalendarView, EventListAppearanceSettingView)

    @MainActor
    func test_appearanceSetting() {
        captureSnapshotPair(named: "appearanceSetting", layout: .fixed(width: 393, height: 2600)) { theme in
            let calendar = CalendarAppearanceSettings(
                colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
                fontSetKey: .systemDefault
            )
            let viewAppearance = self.makeAppearanceSettingViewAppearance(theme)

            let calendarHandler = CalendarSectionAppearanceSettingViewEventHandler()
            let eventOnCalendar = EventOnCalendarViewEventHandler()
            let eventListHandler = EventListAppearanceSettingViewEventHandler()
            let appearanceEventHandler = AppearanceSettingViewEventHandler()

            AppearanceSettingContainerView(
                calendar,
                viewAppearance: viewAppearance,
                calendarSectionEventHandler: calendarHandler,
                eventOnCalendarSectionEventHandler: eventOnCalendar,
                eventListSettingEventHandler: eventListHandler,
                appearanceSettingEventHandler: appearanceEventHandler
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


// MARK: - Test Doubles

/// EventTagDetailViewState의 필드가 fileprivate라 state를 직접 채울 수 없어
/// production의 bind(viewModel:) 경로로 상태를 주입하기 위한 최소 스텁.
private final class FakeEventTagDetailViewModel: EventTagDetailViewModel, @unchecked Sendable {

    var originalName: String? = "some name".localized()
    var suggestColorHexes: [String] = [
        "#F42D2D", "#F9316D", "#FF5722", "#FD838F", "#FFA02E", "#F6DC41", "#B75F17",
        "#6800f2", "#9370DB", "#6A5ACD", "#4034AB", "#1E90FF", "#4682B4",
        "#5F9EA0", "#4561DB", "#5e86d6", "#87CEEB", "#088CDA", "#AFEEEE",
        "#036A73", "#3CB371",
        "#06A192", "#41E6EC", "#72E985",
        "#CCD0DC", "#828DA9", "#8DACF6",
    ]
    var isDeletable: Bool = true
    var isNameChangable: Bool = true
    var originalColorHex: AnyPublisher<String, Never> {
        Just("#ff0000").eraseToAnyPublisher()
    }
    var selectedColorHex: AnyPublisher<String, Never> {
        Just("#ff0000").eraseToAnyPublisher()
    }
    var isSavable: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }
    var isProcessing: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    func selectColor(_ color: String) { }
    func enterName(_ name: String) { }
    func delete() { }
    func save() { }
}

/// ColorThemeSelectViewState의 필드도 fileprivate라 동일한 이유로 bind(viewModel:) 경로를 쓴다.
private final class FakeColorThemeSelectViewModel: ColorThemeSelectViewModel, @unchecked Sendable {

    var sampleModel: AnyPublisher<CalendarAppearanceModel, Never> {
        Just(.init(.sunday)).eraseToAnyPublisher()
    }
    var colorThemeModels: AnyPublisher<[ColorThemeModel], Never> {
        Just([
            .init(.systemTheme) |> \.isSelected .~ true,
            .init(.defaultLight),
            .init(.defaultDark)
        ]).eraseToAnyPublisher()
    }

    func prepare() { }
    func selectTheme(_ model: ColorThemeModel) { }
    func close() { }
}
