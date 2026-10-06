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
    func notifyCalendarSettingChanged(_ newSetting: CalendarAppearanceSettings)
    func notifyDefaultEventTagColorChanged(_ newSetting: DefaultEventTagColorSetting)
    func applyEventTagColors(_ tags: [any EventTag])
}


// MARK: - UISettingUsecase

public protocol UISettingUsecase: Sendable {
    
    func loadSavedAppearanceSetting() -> AppearanceSettings
    func refreshAppearanceSetting() async throws -> AppearanceSettings
    func loadAvailableColorThemes() async throws -> [ColorSetKeys]
    func applyEventTagColors(_ tags: [any EventTag])
    func loadCustomColorThemes() async throws -> [CustomColorTheme]
    func saveCustomColorTheme(_ theme: CustomColorTheme) async throws
    func removeCustomColorTheme(_ uuid: String) async throws
    
    func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings

    func selectCustomColorTheme(_ theme: CustomColorTheme) throws -> CalendarAppearanceSettings

    func changeDefaultEventTagColor(
        _ params: EditDefaultEventTagColorParams
    ) async throws -> DefaultEventTagColorSetting
    
    func changeWidgetAppearanceSetting(
        _ params: EditWidgetAppearanceSettingParams
    ) throws -> WidgetAppearanceSettings
    
    var currentCalendarUISeting: AnyPublisher<CalendarAppearanceSettings, Never> { get }
}
