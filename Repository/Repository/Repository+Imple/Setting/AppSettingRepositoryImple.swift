//
//  AppSettingRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Domain


public final class AppSettingRepositoryImple: AppSettingRepository {
    
    private let environmentStorage: EnvironmentStorage
    
    public init(environmentStorage: EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }
    
    private var colorSetKey: String { "color_set" }
    private var fontSetKey: String { "font_set" }
}


extension AppSettingRepositoryImple {
    
    public func loadSavedViewAppearance() -> AppearanceSettings {
        let colorSetRaw: String? = self.environmentStorage.load(colorSetKey)
        let fontSetRaw: String? = self.environmentStorage.load(fontSetKey)
        let colorSet = colorSetRaw.flatMap { ColorSetKeys(rawValue: $0) } ?? .defaultLight
        let fontSet = fontSetRaw.flatMap { FontSetKeys(rawValue: $0) } ?? .systemDefault
        
        return AppearanceSettings(colorSetKey: colorSet, fontSetKey: fontSet)
    }
    
    public func saveViewAppearanceSetting(_ newValue: AppearanceSettings) {
        self.environmentStorage.update(
            self.colorSetKey, newValue.colorSetKey.rawValue
        )
        self.environmentStorage.update(
            self.fontSetKey, newValue.fontSetKey.rawValue
        )
    }
}
