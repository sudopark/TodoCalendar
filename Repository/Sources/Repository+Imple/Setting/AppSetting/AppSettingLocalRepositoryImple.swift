//
//  AppSettingRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Prelude
import Optics
import Domain


public final class AppSettingLocalRepositoryImple: AppSettingRepository {
    
    private let storage: AppSettingLocalStorage
    
    public init(
        storage: AppSettingLocalStorage
    ) {
        self.storage = storage
    }
}


// MARK: - appearance setting

extension AppSettingLocalRepositoryImple {
    
    public func loadSavedViewAppearance() -> AppearanceSettings {
        return self.storage.loadViewAppearance(for: nil)
    }
    
    public func refreshAppearanceSetting() async throws -> AppearanceSettings {
        return self.storage.loadViewAppearance(for: nil)
    }
    
    private func saveViewAppearanceSetting(_ newValue: AppearanceSettings) {
        self.storage.saveViewAppearance(newValue, for: nil)
    }
    
    public func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings {
        let setting = self.storage.loadCalendarAppearanceSetting(for: nil)
        
        let newSetting = setting.update(params)
        
        self.storage.updateCalendarAppearanceSetting(newSetting, for: nil)
        
        return newSetting
    }
    
    public func changeDefaultEventTagColor(_ params: EditDefaultEventTagColorParams) async throws -> DefaultEventTagColorSetting {
        let setting = self.storage.loadDefaultTagColorSetting(for: nil)
        let newSetting = setting.update(params)
        self.storage.updateDefaultEventTagColors(newSetting, for: nil)
        return newSetting
    }
}


// MARK: - event setting

extension AppSettingLocalRepositoryImple {
    
    public func loadEventSetting() -> EventSettings {
        return self.storage.loadEventSetting(for: nil)
    }

    public func changeEventSetting(_ params: EditEventSettingsParams) -> EventSettings {
        let old = self.storage.loadEventSetting(for: nil)
        let newSetting = old.update(params)
        self.storage.saveEventSetting(newSetting, for: nil)
        return newSetting
    }
}
