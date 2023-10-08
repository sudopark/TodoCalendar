//
//  UISettingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/10/08.
//

import XCTest
import UnitTestHelpKit
@testable import Domain


class UISettingUsecaseImpleTests: BaseTestCase {
        
    private func makeUsecase() -> UISettingUsecaseImple {
        let repository = StubAppSettingRepository()
        let usecase = UISettingUsecaseImple(appSettingRepository: repository)
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
}
