//
//  StubAppSettingRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/10/08.
//

import Foundation

@testable import Domain


class StubAppSettingRepository: AppSettingRepository, @unchecked Sendable {
    
    var stubAppearanceSetting: AppearanceSettings?
    func loadSavedViewAppearance() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            return setting
        }
        return .init(
            tagColorSetting: .init(holiday: "holiday", default: "default"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
    }
    
    func saveViewAppearanceSetting(_ newValue: AppearanceSettings) {
        self.stubAppearanceSetting = newValue
    }
    
    func changeAppearanceSetting(_ params: EditAppearanceSettingParams) -> AppearanceSettings {
        let old = self.loadSavedViewAppearance()
        let newSetting = AppearanceSettings(
            tagColorSetting: .init(
                holiday: params.newTagColorSetting?.newHolidayTagColor ?? old.tagColorSetting.holiday,
                default: params.newTagColorSetting?.newDefaultTagColor ?? old.tagColorSetting.default),
            colorSetKey: params.newColorSetKey ?? old.colorSetKey,
            fontSetKey: params.newFontSetKcy ?? old.fontSetKey
        )
        return newSetting
    }
}