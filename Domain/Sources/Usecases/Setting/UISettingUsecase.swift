//
//  UISettingUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/10/08.
//

import Foundation
import Combine
import Extensions


// MARK:- view apeprance store

public protocol ViewAppearanceStore: Sendable {
    
    func notifySettingChanged(_ newSetting: AppearanceSettings)
}


// MARK: - UISettingUsecase

public protocol UISettingUsecase: Sendable {
    
    func loadAppearanceSetting() -> AppearanceSettings
    
    func changeAppearanceSetting(
        _ params: EditAppearanceSettingParams
    ) throws -> AppearanceSettings
    
    var currentUISeting: AnyPublisher<AppearanceSettings, Never> { get }
}


public final class UISettingUsecaseImple: UISettingUsecase {
    
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

extension UISettingUsecaseImple {
    
    private var key: String { ShareDataKeys.uiSetting.rawValue }
    
    public func loadAppearanceSetting() -> AppearanceSettings {
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        sharedDataStore.put(AppearanceSettings.self, key: self.key, setting)
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
        self.sharedDataStore.put(AppearanceSettings.self, key: self.key, newSetting)
        return newSetting
    }
    
    public var currentUISeting: AnyPublisher<AppearanceSettings, Never> {
        return self.sharedDataStore
            .observe(AppearanceSettings.self, key: self.key)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
