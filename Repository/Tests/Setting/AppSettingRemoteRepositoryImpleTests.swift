//
//  AppSettingRemoteRepositoryImpleTests.swift
//  Repository
//
//  Created by sudo.park on 4/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Domain
import UnitTestHelpKit

@testable import Repository


class AppSettingRemoteRepositoryImpleTests: BaseTestCase {
    
    private var spyStorage: AppSettingLocalStorage!
    override func setUpWithError() throws {
        self.spyStorage = .init(environmentStorage: FakeEnvironmentStorage())
    }
    
    override func tearDownWithError() throws {
        self.spyStorage = nil
    }
    
    private func makeRepository() -> AppSettingRemoteRepositoryImple {
        let remote = StubRemoteAPI(responses: self.response)
        self.spyStorage.saveViewAppearance(self.dummyOldAppearance, for: "some")
        self.spyStorage.saveEventSetting(self.dummyOldEventSetting, for: "some")
        return .init(userId: "some", remoteAPI: remote, storage: self.spyStorage)
    }
    private var dummyOldAppearance: AppearanceSettings {
        let old = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "old_holiday", default: "old_default")
        )
        return old
    }
    private var dummyOldEventSetting: EventSettings {
        var old = EventSettings()
        old.defaultNewEventTagId = .custom("old")
        old.defaultNewEventPeriod = .allDay
        return old
    }
}

extension AppSettingRemoteRepositoryImpleTests {
    
    func testRepository_refreshAppearanceSetting() async throws {
        // given
        let repository = self.makeRepository()
        let settingBeforeRefresh = repository.loadSavedViewAppearance()
        
        // when
        let setting = try await repository.refreshAppearanceSetting()
        
        // then
        XCTAssertEqual(settingBeforeRefresh.defaultTagColor.holiday, "old_holiday")
        XCTAssertEqual(settingBeforeRefresh.defaultTagColor.default, "old_default")
        XCTAssertEqual(setting.defaultTagColor.holiday, "holiday_color")
        XCTAssertEqual(setting.defaultTagColor.default, "default_color")
        
        let settingsAfterRefresh = self.spyStorage.loadViewAppearance(for: "some")
        XCTAssertEqual(setting.defaultTagColor, settingsAfterRefresh.defaultTagColor)
    }
    
    func testRepository_updateViewAppearance() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        var params = EditDefaultEventTagColorParams()
        params.newHolidayTagColor = "new"
        let newSetting = try await repository.changeDefaultEventTagColor(params)
        
        // then
        XCTAssertEqual(newSetting.holiday, "new_holiday_color")
        XCTAssertEqual(newSetting.default, "new_default_color")
        let settingAfterUpdate = self.spyStorage.loadDefaultTagColorSetting(for: "some")
        XCTAssertEqual(newSetting, settingAfterUpdate)
    }
    
    func testRepository_changeEventSetting() {
        // given
        let repository = self.makeRepository()
        
        // when
        var params = EditEventSettingsParams()
        params.defaultNewEventTagId = .custom("new")
        params.defaultNewEventPeriod = .allDay
        let newSetting = repository.changeEventSetting(params)
        
        // then
        XCTAssertEqual(newSetting.defaultNewEventTagId, .custom("new"))
        XCTAssertEqual(newSetting.defaultNewEventPeriod, .allDay)
        let settingAfterUpdate = self.spyStorage.loadEventSetting(for: "some")
        XCTAssertEqual(newSetting, settingAfterUpdate)
    }
}

private extension AppSettingRemoteRepositoryImpleTests {
    
    var colorSettingResponse: String {
        return """
        { "holiday": "holiday_color", "default": "default_color" }
        """
    }
    
    var newcolorSettingResponse: String {
        return """
        { "holiday": "new_holiday_color", "default": "new_default_color" }
        """
    }
    
    var response: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                method: .get,
                endpoint: AppSettingEndpoints.defaultEventTagColor,
                resultJsonString: .success(self.colorSettingResponse)
            ),
            .init(
                method: .patch,
                endpoint: AppSettingEndpoints.defaultEventTagColor,
                resultJsonString: .success(self.newcolorSettingResponse)
            )
        ]
    }
}
