//
//  UISettingUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/10/08.
//

import Foundation


public protocol UISettingUsecase: Sendable {
    
    func loadAppearanceSetting() -> AppearanceSettings
}


public final class UISettingUsecaseImple: UISettingUsecase {
    
    private let appSettingRepository: any AppSettingRepository
    
    public init(appSettingRepository: any AppSettingRepository) {
        self.appSettingRepository = appSettingRepository
    }
}

extension UISettingUsecaseImple {
    
    public func loadAppearanceSetting() -> AppearanceSettings {
        return self.appSettingRepository.loadSavedViewAppearance()
    }
}
