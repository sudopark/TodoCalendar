//
//  AppSettingRemoteRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 4/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


public final class AppSettingRemoteRepositoryImple: AppSettingRepository {
    
    private let userId: String
    private let remoteAPI: any RemoteAPI
    private let storage: AppSettingLocalStorage
    
    public init(
        userId: String,
        remoteAPI: any RemoteAPI,
        storage: AppSettingLocalStorage
    ) {
        self.userId = userId
        self.remoteAPI = remoteAPI
        self.storage = storage
    }
}


// MARK: - appearance setting

extension AppSettingRemoteRepositoryImple {
    
    public func loadSavedViewAppearance() -> AppearanceSettings {
        return self.storage.loadViewAppearance(for: self.userId)
    }
    
    public func refreshAppearanceSetting() async throws -> AppearanceSettings {
        let appearance = self.loadSavedViewAppearance()
        let defColorSetting = try await self.loadDefaultEventTagColorSetting()
        let newApeparance = appearance |> \.defaultTagColor .~ defColorSetting
        self.storage.saveViewAppearance(newApeparance, for: self.userId)
        return newApeparance
    }
    
    public func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings {
        let setting = self.storage.loadCalendarAppearanceSetting(for: self.userId)
        let newSetting = setting.update(params)
        self.storage.updateCalendarAppearanceSetting(newSetting, for: self.userId)
        return newSetting
    }
    
    private func loadDefaultEventTagColorSetting() async throws -> DefaultEventTagColorSetting {
        let mapper: EventTagColorSettingMapper = try await self.remoteAPI.request(
            .get,
            AppSettingEndpoints.defaultEventTagColor
        )
        return mapper.setting
    }
    
    public func changeDefaultEventTagColor(
        _ params: EditDefaultEventTagColorParams
    ) async throws -> DefaultEventTagColorSetting {
        
        let payload = params.asJson()
        let mapper: EventTagColorSettingMapper = try await self.remoteAPI.request(
            .patch,
            AppSettingEndpoints.defaultEventTagColor,
            parameters: payload
        )
        let newSetting = mapper.setting
        self.storage.updateDefaultEventTagColors(newSetting, for: self.userId)
        return newSetting
    }
}


// MARK: - event setting

extension AppSettingRemoteRepositoryImple {
    
    public func loadEventSetting() -> EventSettings {
        return self.storage.loadEventSetting(for: self.userId)
    }
    
    public func changeEventSetting(_ params: EditEventSettingsParams) -> EventSettings {
        let old = self.loadEventSetting()
        let new = old.update(params)
        self.storage.saveEventSetting(new, for: self.userId)
        return new
    }
}
