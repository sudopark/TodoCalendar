//
//  AppSettingUsecase.swift
//  Domain
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


public final class AppSettingUsecaseImple: Sendable {
    
    private let appSettingRepository: any AppSettingRepository
    private let viewAppearanceStore: any ViewAppearanceStore
    private let sharedDataStore: SharedDataStore
    
    public init(
        appSettingRepository: any AppSettingRepository,
        viewAppearanceStore: any ViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.appSettingRepository = appSettingRepository
        self.viewAppearanceStore = viewAppearanceStore
        self.sharedDataStore = sharedDataStore
    }
}

// MARK: - appearance

extension AppSettingUsecaseImple: UISettingUsecase {
    
    private var appearanceKey: String { ShareDataKeys.uiSetting.rawValue }
    
    public func loadAppearanceSetting() -> AppearanceSettings {
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        sharedDataStore.put(AppearanceSettings.self, key: self.appearanceKey, setting)
        return setting
    }
    
    public func changeAppearanceSetting(
        _ params: EditAppearanceSettingParams
    ) throws -> AppearanceSettings {
        guard params.isValid
        else {
            throw RuntimeError("invalid edit appearance params")
        }
        let newSetting = self.appSettingRepository.changeAppearanceSetting(params)
        self.viewAppearanceStore.notifySettingChanged(newSetting)
        self.sharedDataStore.put(AppearanceSettings.self, key: self.appearanceKey, newSetting)
        return newSetting
    }
    
    public var currentUISeting: AnyPublisher<AppearanceSettings, Never> {
        return self.sharedDataStore
            .observe(AppearanceSettings.self, key: self.appearanceKey)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}


// MARK: - EventSetting


extension AppSettingUsecaseImple: EventSettingUsecase {
    
    private var eventSettingKey: String { ShareDataKeys.eventSetting.rawValue }
    
    public func loadEventSetting() -> EventSettings {
        let setting = self.appSettingRepository.loadEventSetting()
        self.sharedDataStore.put(EventSettings.self, key: eventSettingKey, setting)
        return setting
    }
    
    public func changeEventSetting(_ params: EditEventSettingsParams) throws -> EventSettings {
        guard params.isValid
        else {
            throw RuntimeError("invalid edit parameters")
        }
        let newSetting = self.appSettingRepository.changeEventSetting(params)
        self.sharedDataStore.put(EventSettings.self, key: eventSettingKey, newSetting)
        return newSetting
    }
    
    public var currentEventSetting: AnyPublisher<EventSettings, Never> {
        return self.sharedDataStore
            .observe(EventSettings.self, key: self.eventSettingKey)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
