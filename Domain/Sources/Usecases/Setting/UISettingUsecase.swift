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
}


public final class UISettingUsecaseImple: UISettingUsecase {
    
    private let appSettingRepository: any AppSettingRepository
    private let viewAppearanceStore: any ViewAppearanceStore
    
    public init(
        appSettingRepository: any AppSettingRepository,
        viewAppearanceStore: any ViewAppearanceStore
    ) {
        self.appSettingRepository = appSettingRepository
        self.viewAppearanceStore = viewAppearanceStore
    }
}

extension UISettingUsecaseImple {
    
    public func loadAppearanceSetting() -> AppearanceSettings {
        return self.appSettingRepository.loadSavedViewAppearance()
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
        return newSetting
    }
}
