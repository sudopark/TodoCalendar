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
        let newSetting = old.update(params)
        return newSetting
    }
}
