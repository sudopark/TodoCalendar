//
//  StubUISettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/10/09.
//

import Foundation
import Domain
import Prelude
import Optics

open class StubUISettingUsecase: UISettingUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var stubAppearanceSetting: AppearanceSettings?
    open func loadAppearanceSetting() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            return setting
        }
        return AppearanceSettings(
            tagColorSetting: .init(holiday: "holiday", default: "default"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
    }
    
    public var didChangeAppearanceSetting: AppearanceSettings?
    open func changeAppearanceSetting(_ params: EditAppearanceSettingParams) throws -> AppearanceSettings {
        let old = self.loadAppearanceSetting()
        let newSetting = old.update(params)
        self.didChangeAppearanceSetting = newSetting
        self.stubAppearanceSetting = newSetting
        return newSetting
    }
}
