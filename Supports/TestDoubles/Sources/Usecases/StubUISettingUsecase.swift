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
    
    public func loadSavedAppearanceSetting() -> AppearanceSettings {
        let setting = self.readSetting()
        self.settingSubject.send(setting)
        return setting
    }
    
    private let settingSubject = CurrentValueSubject<AppearanceSettings?, Never>(nil)
    open func refreshAppearanceSetting() async throws -> AppearanceSettings {
        let setting = self.readSetting()
        self.settingSubject.send(setting)
        return setting
    }
    
    private func readSetting() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            return setting
        }
        let tag = DefaultEventTagColorSetting(holiday: "holiday", default: "default")
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: tag
        )
        return setting
    }
    
    public var didChangeAppearanceSetting: AppearanceSettings?
    
    open func changeCalendarAppearanceSetting(_ params: EditCalendarAppearanceSettingParams) throws -> CalendarAppearanceSettings {
        let old = self.readSetting()
        let newSetting = old |> \.calendar .~ old.calendar.update(params)
        self.didChangeAppearanceSetting = newSetting
        self.stubAppearanceSetting = newSetting
        self.settingSubject.send(newSetting)
        return newSetting.calendar
    }
    
    public var didDetaulEventTagColorChangedCallback: (() -> Void)?
    public func changeDefaultEventTagColor(_ params: EditDefaultEventTagColorParams) async throws -> DefaultEventTagColorSetting {
        let old = self.readSetting()
        let newSetting = old |> \.defaultTagColor .~ old.defaultTagColor.update(params)
        self.didChangeAppearanceSetting = newSetting
        self.stubAppearanceSetting = newSetting
        self.settingSubject.send(newSetting)
        self.didDetaulEventTagColorChangedCallback?()
        return newSetting.defaultTagColor
    }
    
    public var currentCalendarUISeting: AnyPublisher<CalendarAppearanceSettings, Never> {
        return self.settingSubject
            .compactMap { $0?.calendar }
            .eraseToAnyPublisher()
    }
}
