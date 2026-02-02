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
import TestDoubles

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
    
    func testUsecase_loadAppAppearanceSetting() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let setting = try await usecase.refreshAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.defaultTagColor.holiday, "holiday")
        XCTAssertEqual(setting.defaultTagColor.default, "default")
        XCTAssertEqual(setting.calendar.colorSetKey, .defaultLight)
        XCTAssertEqual(setting.calendar.fontSetKey, .systemDefault)
    }
    
    func testUsecase_whenAfterLoadSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 조회 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentCalendarUISeting) {
            Task {
                let _ = try await usecase.refreshAppearanceSetting()
            }
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testUsecase_whenchangeCalendarSettingWithInsufficientParams_error() {
        // given
        let usecase = self.makeUsecase()
        var failed: Error?
        // when
        let params = EditCalendarAppearanceSettingParams()
        do {
            _ = try usecase.changeCalendarAppearanceSetting(params)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testUsecase_changeCalendarAppearnaceSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditCalendarAppearanceSettingParams()
            |> \.animationEffectIsOn .~ true
        let newValue = try? usecase.changeCalendarAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValue?.animationEffectIsOn, true)
    }
    
    func testUsecase_whenAfterchangeCalendarSetting_notifyToViewAppearanceStore() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditCalendarAppearanceSettingParams()
            |> \.animationEffectIsOn .~ true
        let _ = try? usecase.changeCalendarAppearanceSetting(params)
        
        // then
        XCTAssertEqual(self.spyViewAppearanceStore.didChangedCalendarSetting?.animationEffectIsOn, true)
    }
    
    func testUsecase_whenChangetagSettingWithInsufficientParams_error() async {
        // given
        let usecase = self.makeUsecase()
        var failed: Error?
        // when
        let params = EditDefaultEventTagColorParams()
        do {
            _ = try await usecase.changeDefaultEventTagColor(params)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testUsecase_changeDefaultTagColorAppearnaceSetting() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditDefaultEventTagColorParams()
            |> \.newDefaultTagColor .~ "new"
        let newValue = try? await usecase.changeDefaultEventTagColor(params)
        
        // then
        XCTAssertEqual(newValue?.default, "new")
    }
    
    func testUsecase_whenAfterChangeTagColorSetting_notifyToViewAppearanceStore() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditDefaultEventTagColorParams()
            |> \.newDefaultTagColor .~ "new"
        let _ = try? await usecase.changeDefaultEventTagColor(params)
        
        // then
        XCTAssertEqual(self.spyViewAppearanceStore.didChangedDefaultTagColor?.default, "new")
    }
    
    func testUsecase_whenAfterChangeSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 변경 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentCalendarUISeting) {
            let params = EditCalendarAppearanceSettingParams()
                |> \.animationEffectIsOn .~ true
            let _ = try? usecase.changeCalendarAppearanceSetting(params)
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testUsecase_changeWidgetAppearnaceSetting() throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditWidgetAppearanceSettingParams() |> \.background .~ .custom(hex: "custom")
        let newValue = try usecase.changeWidgetAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValue.background, .custom(hex: "custom"))
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
        XCTAssertEqual(setting.defaultNewEventPeriod, .minute0)
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
    
    var didChangedCalendarSetting: CalendarAppearanceSettings?
    func notifyCalendarSettingChanged(_ newSetting: CalendarAppearanceSettings) {
        self.didChangedCalendarSetting = newSetting
    }
    
    var didChangedDefaultTagColor: DefaultEventTagColorSetting?
    func notifyDefaultEventTagColorChanged(_ newSetting: DefaultEventTagColorSetting) {
        self.didChangedDefaultTagColor = newSetting
    }
    
    func applyEventTagColors(_ tags: [any EventTag]) { }
}
