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
