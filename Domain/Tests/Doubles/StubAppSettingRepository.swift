//
//  StubAppSettingRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/10/08.
//

import Foundation
import Prelude
import Optics

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
    
    var stubEvnetSetting: EventSettings?
    func loadEventSetting() -> EventSettings {
        if let setting = self.stubEvnetSetting {
            return setting
        }
        return EventSettings()
    }
    
    func changeEventSetting(_ params: EditEventSettingsParams) -> EventSettings {
        let old = self.loadEventSetting()
        let newSetting = old
        |> \.defaultNewEventTagId .~ (params.defaultNewEventTagId ?? old.defaultNewEventTagId)
        |> \.defaultNewEventPeriod .~ (params.defaultNewEventPeriod ?? old.defaultNewEventPeriod)
        return newSetting
    }
}
