//
//  StubUISettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/10/09.
//

import Foundation
import Combine
import Domain
import Extensions
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
    
    public func loadAvailableColorThemes() async throws -> [ColorSetKeys] {
        return [.systemTheme, .defaultLight, .defaultDark]
            + AppThemeColorSetKey.allCases.map { ColorSetKeys.appTheme($0) }
    }
    
    public var stubCustomColorThemes: [CustomColorTheme] = []
    open func loadCustomColorThemes() async throws -> [CustomColorTheme] {
        return self.stubCustomColorThemes
    }
    
    public var shouldFailSaveCustomColorTheme: Bool = false
    public var didSaveCustomColorTheme: CustomColorTheme?
    open func saveCustomColorTheme(_ theme: CustomColorTheme) async throws {
        guard self.shouldFailSaveCustomColorTheme == false
        else { throw RuntimeError("failed") }
        self.didSaveCustomColorTheme = theme
    }
    
    public var shouldFailRemoveCustomColorTheme: Bool = false
    public var didRemoveCustomColorThemeUuid: String?
    public func removeCustomColorTheme(_ uuid: String) async throws {
        guard self.shouldFailRemoveCustomColorTheme == false
        else { throw RuntimeError("failed") }
        self.didRemoveCustomColorThemeUuid = uuid
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

    public var didSelectCustomColorTheme: CustomColorTheme?
    open func selectCustomColorTheme(_ theme: CustomColorTheme) throws -> CalendarAppearanceSettings {
        let old = self.readSetting()
        let params = EditCalendarAppearanceSettingParams() |> \.newColorSetKey .~ .custom(theme.uuid)
        let calendarAfterUpdate = old.calendar.update(params)
        let newCalendar = calendarAfterUpdate |> \.currentCustomColorTheme .~ theme
        let newSetting = old |> \.calendar .~ newCalendar
        self.didSelectCustomColorTheme = theme
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
    
    open func changeWidgetAppearanceSetting(_ params: EditWidgetAppearanceSettingParams) throws -> WidgetAppearanceSettings {
        let old = self.readSetting()
        let new = old.widget.update(params)
        let newSetting = old |> \.widget .~ new
        self.didChangeAppearanceSetting = newSetting
        self.stubAppearanceSetting = newSetting
        self.settingSubject.send(newSetting)
        return newSetting.widget
    }
    
    public var currentCalendarUISeting: AnyPublisher<CalendarAppearanceSettings, Never> {
        return self.settingSubject
            .compactMap { $0?.calendar }
            .eraseToAnyPublisher()
    }
    
    public var didAppluEventTagColorCallback: (() -> Void)?
    public var didApplyTagColorsRequestedWith: [any EventTag]?
    public func applyEventTagColors(_ tags: [any EventTag]) {
        self.didApplyTagColorsRequestedWith = tags
        self.didAppluEventTagColorCallback?()
    }
}
