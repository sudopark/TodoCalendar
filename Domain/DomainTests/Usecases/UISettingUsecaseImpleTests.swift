//
//  UISettingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/10/08.
//

import XCTest
import Prelude
import Optics
import UnitTestHelpKit
@testable import Domain


class UISettingUsecaseImpleTests: BaseTestCase {
    
    private var spyViewAppearanceStore: SpyViewAppearanceStore!
    
    override func setUpWithError() throws {
        self.spyViewAppearanceStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyViewAppearanceStore = nil
    }
        
    private func makeUsecase() -> UISettingUsecaseImple {
        let repository = StubAppSettingRepository()
        let usecase = UISettingUsecaseImple(
            appSettingRepository: repository,
            viewAppearanceStore: self.spyViewAppearanceStore
        )
        return usecase
    }
}


extension UISettingUsecaseImpleTests {
    
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
        let newValeu = try? usecase.changeAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValeu?.tagColorSetting.holiday, "new")
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
        let newValeu = try? usecase.changeAppearanceSetting(params)
        
        // then
        XCTAssertEqual(self.spyViewAppearanceStore.didSettignCahngedTo?.tagColorSetting.holiday, "new")
    }
}


private class SpyViewAppearanceStore: ViewAppearanceStore, @unchecked Sendable {
 
    var didSettignCahngedTo: AppearanceSettings?
    func notifySettingChanged(_ newSetting: AppearanceSettings) {
        self.didSettignCahngedTo = newSetting
    }
}
