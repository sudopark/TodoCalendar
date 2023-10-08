//
//  AppSettingRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation


public protocol AppSettingRepository: Sendable {
    
    func loadSavedViewAppearance() -> AppearanceSettings
    func saveViewAppearanceSetting(_ newValue: AppearanceSettings)
    func changeAppearanceSetting(_ params: EditAppearanceSettingParams) -> AppearanceSettings
}
