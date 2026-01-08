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
}
