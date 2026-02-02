//
//  AppSettingRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation


public protocol AppSettingRepository: Sendable {
    
    func loadSavedViewAppearance() -> AppearanceSettings
    func refreshAppearanceSetting() async throws -> AppearanceSettings
    
    func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings
    
    func changeDefaultEventTagColor(
        _ params: EditDefaultEventTagColorParams
    ) async throws -> DefaultEventTagColorSetting
    
    
    func loadEventSetting() -> EventSettings
    func changeEventSetting(_ params: EditEventSettingsParams) -> EventSettings
    
    func loadWidgetAppearanceSetting() -> WidgetAppearanceSettings
    func updateWidgetAppearance(
        _ params: EditWidgetAppearanceSettingParams
    ) -> WidgetAppearanceSettings
}
