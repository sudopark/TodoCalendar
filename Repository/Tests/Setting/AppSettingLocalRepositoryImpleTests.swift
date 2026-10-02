//
//  AppSettingLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/08/07.
//

import XCTest
import Prelude
import Optics
import Domain
import UnitTestHelpKit

@testable import Repository


class AppSettingLocalRepositoryImpleTests: BaseTestCase {
    
    private func makeRepository() -> AppSettingLocalRepositoryImple {
        let storage = AppSettingLocalStorage(environmentStorage: FakeEnvironmentStorage())
        return .init(storage: storage)
    }
}


extension AppSettingLocalRepositoryImpleTests {
    
    func testRepository_whenSavedAppearanceNotExists_returnWithDefaultValue() {
        // given
        let repository = self.makeRepository()
        
        // when
        let appearance = repository.loadSavedViewAppearance()
        
        // then
        XCTAssertEqual(appearance.calendar.colorSetKey, .systemTheme)
        XCTAssertEqual(appearance.calendar.fontSetKey, .systemDefault)
        XCTAssertEqual(appearance.calendar.showUnderLineOnEventDay, true)
        XCTAssertEqual(appearance.calendar.accnetDayPolicy, [
            .holiday: false, .sunday: false, .saturday: false
        ])
        XCTAssertEqual(appearance.calendar.rowHeight, .medium)
        XCTAssertEqual(appearance.calendar.showUncompletedTodos, true)
        XCTAssertEqual(appearance.widget.background, .system)
    }
    
    func testRepository_saveAndLoadWidgetAppearanceSetting() {
        // given
        let repository = self.makeRepository()
        
        // when + then
        let initial = repository.loadWidgetAppearanceSetting()
        XCTAssertEqual(
            initial,
            WidgetAppearanceSettings() |> \.background .~ .system
        )
        
        var params = EditWidgetAppearanceSettingParams()
        params.background = .custom(hex: "custom")
        let updated = repository.updateWidgetAppearance(params)
        XCTAssertEqual(
            updated,
            WidgetAppearanceSettings() |> \.background .~ .custom(hex: "custom")
        )
    }
    
    func testRepository_updateCalendarSetting() throws {
        // given
        let repository = self.makeRepository()
        let settingBeforeUpdate = repository.loadSavedViewAppearance().calendar
        
        // when
        let params = EditCalendarAppearanceSettingParams()
            |> \.rowHeight .~ .large
        let changed = try repository.changeCalendarAppearanceSetting(params)
        let settingAfterUpdate = repository.loadSavedViewAppearance().calendar
        
        // then
        XCTAssertEqual(settingBeforeUpdate.rowHeight, .medium)
        XCTAssertEqual(changed.rowHeight, .large)
        XCTAssertEqual(settingAfterUpdate.rowHeight, .large)
    }
    
    func testStorage_saveCalendarSettingWithCurrentCustomTheme_doesNotPersistTheme() {
        // given
        let storage = AppSettingLocalStorage(environmentStorage: FakeEnvironmentStorage())
        let theme = CustomColorTheme(
            uuid: "c1", name: "t", schemaVersion: 1,
            seeds: .init(background: "#FFFFFF", accent: "#112233", form: .filled),
            colors: [:], createdAt: 0, updatedAt: 0
        )
        let calendar = CalendarAppearanceSettings(colorSetKey: .custom("c1"), fontSetKey: .systemDefault)
            |> \.currentCustomColorTheme .~ theme
        let appearance = AppearanceSettings(
            calendar: calendar, defaultTagColor: .init(holiday: "", default: "")
        )
        
        // when
        storage.saveViewAppearance(appearance, for: nil)
        let loaded = storage.loadCalendarAppearanceSetting(for: nil)
        
        // then
        XCTAssertEqual(loaded.colorSetKey, .custom("c1"))
        XCTAssertNil(loaded.currentCustomColorTheme)
    }
    
    func testRepository_saveAndLoadEventSetting() {
        // given
        let repository = self.makeRepository()
        
        // when + then
        let initial = repository.loadEventSetting()
        XCTAssertEqual(
            initial,
            EventSettings()
                |> \.defaultNewEventTagId .~ .default
                |> \.defaultNewEventPeriod .~ .minute0
                |> \.defaultMapApp .~ nil
        )
        
        var params = EditEventSettingsParams() |> \.defaultNewEventTagId .~ .custom("some")
        let tagUpdated = repository.changeEventSetting(params)
        XCTAssertEqual(
            tagUpdated,
            EventSettings()
                |> \.defaultNewEventTagId .~ .custom("some")
                |> \.defaultNewEventPeriod .~ .minute0
                |> \.defaultMapApp .~ nil
        )
        
        params = EditEventSettingsParams() |> \.defaultNewEventPeriod .~ .hour1
        let periodUpdated = repository.changeEventSetting(params)
        XCTAssertEqual(
            periodUpdated,
            EventSettings()
                |> \.defaultNewEventTagId .~ .custom("some")
                |> \.defaultNewEventPeriod .~ .hour1
                |> \.defaultMapApp .~ nil
        )
        
        params = EditEventSettingsParams() |> \.defaultMappApp .~ .google
        let mapAppUpdated = repository.changeEventSetting(params)
        XCTAssertEqual(
            mapAppUpdated,
            EventSettings()
                |> \.defaultNewEventTagId .~ .custom("some")
                |> \.defaultNewEventPeriod .~ .hour1
                |> \.defaultMapApp .~ .google
        )
    }

    func testRepository_loadEventShareSetting_whenNothingSaved_returnsDefault() {
        // given
        let repository = self.makeRepository()

        // when
        let setting = repository.loadEventShareSetting()

        // then
        XCTAssertEqual(setting.includeTagName, false)
    }

    func testRepository_changeEventShareSetting_thenLoadReturnsChangedValue() {
        // given
        let repository = self.makeRepository()
        let params = EditEventShareSettingsParams() |> \.includeTagName .~ true

        // when
        let changed = repository.changeEventShareSetting(params)
        let loaded = repository.loadEventShareSetting()

        // then
        XCTAssertEqual(changed.includeTagName, true)
        XCTAssertEqual(loaded.includeTagName, true)
    }
}
