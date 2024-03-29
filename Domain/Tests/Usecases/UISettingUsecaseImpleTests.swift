//
//  AppSettingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/10/08.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit
@testable import Domain


class AppSettingUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyViewAppearanceStore: SpyViewAppearanceStore!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyViewAppearanceStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyViewAppearanceStore = nil
        self.cancelBag = nil
    }
        
    private func makeUsecase() -> AppSettingUsecaseImple {
        let repository = StubAppSettingRepository()
        let usecase = AppSettingUsecaseImple(
            appSettingRepository: repository,
            viewAppearanceStore: self.spyViewAppearanceStore,
            sharedDataStore: SharedDataStore()
        )
        return usecase
    }
}


// MARK: - test ui setting

extension AppSettingUsecaseImpleTests {
    
    func testUsecase_loadAppAppearanceSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let setting = usecase.loadAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.tagColorSetting.holiday, "holiday")
        XCTAssertEqual(setting.tagColorSetting.default, "default")
        XCTAssertEqual(setting.colorSetKey, .defaultLight)
        XCTAssertEqual(setting.fontSetKey, .systemDefault)
    }
    
    func testUsecase_whenAfterLoadSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 조회 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentUISeting) {
            let _ = usecase.loadAppearanceSetting()
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testUsecase_whenChangeSettingWithInsufficientParams_error() {
        // given
        let usecase = self.makeUsecase()
        var failed: Error?
        // when
        let params = EditAppearanceSettingParams()
        do {
            _ = try usecase.changeAppearanceSetting(params)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testUsecase_changeAppearnaceSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditAppearanceSettingParams()
            |> \.newTagColorSetting .~ (
                EditAppearanceSettingParams.EditEventTagColorParams()
                |> \.newHolidayTagColor .~ "new"
            )
        let newValue = try? usecase.changeAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValue?.tagColorSetting.holiday, "new")
    }
    
    func testUsecase_whenAfterChangeSetting_notifyToViewAppearanceStore() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditAppearanceSettingParams()
            |> \.newTagColorSetting .~ (
                EditAppearanceSettingParams.EditEventTagColorParams()
                |> \.newHolidayTagColor .~ "new"
            )
        let _ = try? usecase.changeAppearanceSetting(params)
        
        // then
        XCTAssertEqual(self.spyViewAppearanceStore.didSettignCahngedTo?.tagColorSetting.holiday, "new")
    }
    
    func testUsecase_whenAfterChangeSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 조회 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentUISeting) {
            let params = EditAppearanceSettingParams()
                |> \.newTagColorSetting .~ (
                    EditAppearanceSettingParams.EditEventTagColorParams()
                    |> \.newHolidayTagColor .~ "new"
                )
            let _ = try? usecase.changeAppearanceSetting(params)
        }
        
        // then
        XCTAssertNotNil(setting)
    }
}


// MARK: - test event setting

extension AppSettingUsecaseImpleTests {
    
    func testUsecase_loadEventSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let setting = usecase.loadEventSetting()
        
        // then
        XCTAssertEqual(setting.defaultNewEventTagId, .default)
        XCTAssertEqual(setting.defaultNewEventPeriod, .hour1)
    }
    
    func testUsecase_whenAfterLoadEventSettingSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 조회 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentEventSetting) {
            let _ = usecase.loadEventSetting()
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testUsecase_whenChangeEventSettingWithInsufficientParams_error() {
        // given
        let usecase = self.makeUsecase()
        var failed: Error?
        // when
        let params = EditEventSettingsParams()
        do {
            _ = try usecase.changeEventSetting(params)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testUsecase_changeEventSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditEventSettingsParams()
            |> \.defaultNewEventPeriod .~ .allDay
            |> \.defaultNewEventTagId .~ .holiday
        let newValue = try? usecase.changeEventSetting(params)
        
        // then
        XCTAssertEqual(newValue?.defaultNewEventTagId, .holiday)
        XCTAssertEqual(newValue?.defaultNewEventPeriod, .allDay)
    }
    
    func testUsecase_whenAfterChangeEventSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 업데이트 이후 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentEventSetting) {
            let params = EditEventSettingsParams()
                |> \.defaultNewEventPeriod .~ .allDay
            let _ = try? usecase.changeEventSetting(params)
        }
        
        // then
        XCTAssertNotNil(setting)
    }
}

private class SpyViewAppearanceStore: ViewAppearanceStore, @unchecked Sendable {
 
    var didSettignCahngedTo: AppearanceSettings?
    func notifySettingChanged(_ newSetting: AppearanceSettings) {
        self.didSettignCahngedTo = newSetting
    }
}
