//
//  StubUISettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/10/09.
//

import Foundation
import Domain


open class StubUISettingUsecase: UISettingUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var stubAppearanceSetting: AppearanceSettings?
    open func loadAppearanceSetting() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            return setting
        }
        return .init(
            tagColorSetting: .init(holiday: "holiday", default: "default"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
    }
    
    public var didChangeAppearanceSetting: AppearanceSettings?
    open func changeAppearanceSetting(_ params: EditAppearanceSettingParams) throws -> AppearanceSettings {
        let old = self.loadAppearanceSetting()
        let newSetting = AppearanceSettings(
            tagColorSetting: .init(
                holiday: params.newTagColorSetting?.newHolidayTagColor ?? old.tagColorSetting.holiday,
                default: params.newTagColorSetting?.newDefaultTagColor ?? old.tagColorSetting.default),
            colorSetKey: params.newColorSetKey ?? old.colorSetKey,
            fontSetKey: params.newFontSetKcy ?? old.fontSetKey
        )
        self.didChangeAppearanceSetting = newSetting
        return newSetting
    }
}
