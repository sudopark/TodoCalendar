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
}


// MARK: - UISettingUsecase

public protocol UISettingUsecase: Sendable {
    
    func loadSavedAppearanceSetting() -> AppearanceSettings
    func refreshAppearanceSetting() async throws -> AppearanceSettings
    
    func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings
    
    func changeDefaultEventTagColor(
        _ params: EditDefaultEventTagColorParams
    ) async throws -> DefaultEventTagColorSetting
    
    var currentCalendarUISeting: AnyPublisher<CalendarAppearanceSettings, Never> { get }
}
