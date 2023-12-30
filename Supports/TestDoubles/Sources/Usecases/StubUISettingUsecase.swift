//
//  StubUISettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/10/09.
//

import Foundation
import Combine
import Domain
import Prelude
import Optics

open class StubUISettingUsecase: UISettingUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var stubAppearanceSetting: AppearanceSettings?
    private let settingSubject = CurrentValueSubject<AppearanceSettings?, Never>(nil)
    open func loadAppearanceSetting() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            self.settingSubject.send(setting)
            return setting
        }
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "holiday", default: "default"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        self.settingSubject.send(setting)
        return setting
    }
    
    public var didChangeAppearanceSetting: AppearanceSettings?
    open func changeAppearanceSetting(_ params: EditAppearanceSettingParams) throws -> AppearanceSettings {
        let old = self.loadAppearanceSetting()
        let newSetting = old.update(params)
        self.didChangeAppearanceSetting = newSetting
        self.stubAppearanceSetting = newSetting
        self.settingSubject.send(newSetting)
        return newSetting
    }
    
    public var currentUISeting: AnyPublisher<AppearanceSettings, Never> {
        return self.settingSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
