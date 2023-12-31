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


public protocol AppSettingUsecase: AnyObject, UISettingUsecase { }


public final class AppSettingUsecaseImple: AppSettingUsecase {
    
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

extension AppSettingUsecaseImple {
    
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
