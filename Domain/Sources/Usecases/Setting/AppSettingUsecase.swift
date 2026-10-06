//
//  AppSettingUsecase.swift
//  Domain
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


public final class AppSettingUsecaseImple: @unchecked Sendable {
    
    private let appSettingRepository: any AppSettingRepository
    private let customColorThemeRepository: any CustomColorThemeRepository
    private let viewAppearanceStore: any ViewAppearanceStore
    private let sharedDataStore: SharedDataStore
    
    public init(
        appSettingRepository: any AppSettingRepository,
        customColorThemeRepository: any CustomColorThemeRepository,
        viewAppearanceStore: any ViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.appSettingRepository = appSettingRepository
        self.customColorThemeRepository = customColorThemeRepository
        self.viewAppearanceStore = viewAppearanceStore
        self.sharedDataStore = sharedDataStore
    }
}

// MARK: - appearance

extension AppSettingUsecaseImple: UISettingUsecase {
    
    private var calednarSettingKey: String { ShareDataKeys.calendarAppearance.rawValue }
    private var defaultEventTagColorKey: String { ShareDataKeys.defaultEventTagColor.rawValue }
    
    public func loadSavedAppearanceSetting() -> AppearanceSettings {
        let saved = self.appSettingRepository.loadSavedViewAppearance()
        let setting = saved |> \.calendar .~ self.carryingCurrentCustomColorTheme(saved.calendar)
        self.sharedDataStore.put(
            CalendarAppearanceSettings.self, key: self.calednarSettingKey, setting.calendar
        )
        self.sharedDataStore.put(
            DefaultEventTagColorSetting.self, key: self.defaultEventTagColorKey, setting.defaultTagColor
        )
        self.viewAppearanceStore.notifySettingChanged(setting)
        return setting
    }
    
    public func loadAvailableColorThemes() async throws -> [ColorSetKeys] {
        return [.systemTheme, .defaultLight, .defaultDark]
            + AppThemeColorSetKey.allCases.map { ColorSetKeys.appTheme($0) }
    }
    
    public func applyEventTagColors(_ tags: [any EventTag]) {
        self.viewAppearanceStore.applyEventTagColors(tags)
    }
    
    public func refreshAppearanceSetting() async throws -> AppearanceSettings {
        let refreshed = try await self.appSettingRepository.refreshAppearanceSetting()
        let currentTheme = await self.loadCustomColorTheme(for: refreshed.calendar.colorSetKey)
        let setting = refreshed |> \.calendar.currentCustomColorTheme .~ currentTheme
        self.sharedDataStore.put(
            CalendarAppearanceSettings.self, key: self.calednarSettingKey, setting.calendar
        )
        self.sharedDataStore.put(
            DefaultEventTagColorSetting.self, key: self.defaultEventTagColorKey, setting.defaultTagColor
        )
        self.viewAppearanceStore.notifySettingChanged(setting)
        return setting
    }
    
    public func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings {
        guard params.isValid
        else {
            throw RuntimeError("invalid edit appearance params")
        }
        let changed = try self.appSettingRepository.changeCalendarAppearanceSetting(params)
        let newSetting = self.carryingCurrentCustomColorTheme(changed)
        self.viewAppearanceStore.notifyCalendarSettingChanged(newSetting)
        self.sharedDataStore.put(
            CalendarAppearanceSettings.self, key: self.calednarSettingKey, newSetting
        )
        return newSetting
    }

    public func selectCustomColorTheme(_ theme: CustomColorTheme) throws -> CalendarAppearanceSettings {
        let params = EditCalendarAppearanceSettingParams() |> \.newColorSetKey .~ .custom(theme.uuid)
        let changed = try self.appSettingRepository.changeCalendarAppearanceSetting(params)
        let newSetting = changed |> \.currentCustomColorTheme .~ theme
        self.viewAppearanceStore.notifyCalendarSettingChanged(newSetting)
        self.sharedDataStore.put(
            CalendarAppearanceSettings.self, key: self.calednarSettingKey, newSetting
        )
        return newSetting
    }
    
    public func changeDefaultEventTagColor(
        _ params: EditDefaultEventTagColorParams
    ) async throws -> DefaultEventTagColorSetting {
        guard params.isValid
        else {
            throw RuntimeError("invalid edit appearance params")
        }
        let newSetting = try await self.appSettingRepository.changeDefaultEventTagColor(params)
        self.viewAppearanceStore.notifyDefaultEventTagColorChanged(newSetting)
        self.sharedDataStore.put(
            DefaultEventTagColorSetting.self, key: self.defaultEventTagColorKey, newSetting
        )
        return newSetting
    }
    
    public func changeWidgetAppearanceSetting(
        _ params: EditWidgetAppearanceSettingParams
    ) throws -> WidgetAppearanceSettings {
        guard params.isValid
        else {
            throw RuntimeError("invalid edit widget appearance params")
        }
        
        let newSetting =  self.appSettingRepository.updateWidgetAppearance(params)
        return newSetting
    }
    
    public func loadCustomColorThemes() async throws -> [CustomColorTheme] {
        return try await self.customColorThemeRepository.loadThemes()
    }
    
    public func saveCustomColorTheme(_ theme: CustomColorTheme) async throws {
        try await self.customColorThemeRepository.saveTheme(theme)
        self.replaceCurrentCustomColorTheme(of: theme.uuid, with: theme)
    }
    
    public func removeCustomColorTheme(_ uuid: String) async throws {
        try await self.customColorThemeRepository.removeTheme(uuid)

        guard let current = self.sharedDataStore
            .value(CalendarAppearanceSettings.self, key: self.calednarSettingKey),
              current.colorSetKey == .custom(uuid)
        else {
            return
        }

        let params = EditCalendarAppearanceSettingParams() |> \.newColorSetKey .~ .systemTheme
        _ = try self.changeCalendarAppearanceSetting(params)
    }
    
    private func loadCustomColorTheme(for colorSetKey: ColorSetKeys) async -> CustomColorTheme? {
        guard case .custom(let themeId) = colorSetKey else { return nil }
        return try? await self.customColorThemeRepository.loadTheme(themeId)
    }
    
    private func carryingCurrentCustomColorTheme(
        _ setting: CalendarAppearanceSettings
    ) -> CalendarAppearanceSettings {
        guard case .custom = setting.colorSetKey,
              let current = self.sharedDataStore
                .value(CalendarAppearanceSettings.self, key: self.calednarSettingKey),
              current.colorSetKey == setting.colorSetKey
        else { return setting }
        return setting |> \.currentCustomColorTheme .~ current.currentCustomColorTheme
    }
    
    private func replaceCurrentCustomColorTheme(of uuid: String, with theme: CustomColorTheme) {
        guard let current = self.sharedDataStore
            .value(CalendarAppearanceSettings.self, key: self.calednarSettingKey),
              current.colorSetKey == .custom(uuid)
        else { return }
        let newSetting = current |> \.currentCustomColorTheme .~ theme
        self.viewAppearanceStore.notifyCalendarSettingChanged(newSetting)
        self.sharedDataStore.put(
            CalendarAppearanceSettings.self, key: self.calednarSettingKey, newSetting
        )
    }
    
    public var currentCalendarUISeting: AnyPublisher<CalendarAppearanceSettings, Never> {
        return self.sharedDataStore
            .observe(CalendarAppearanceSettings.self, key: self.calednarSettingKey)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}


// MARK: - EventSetting


extension AppSettingUsecaseImple: EventSettingUsecase {
    
    private var eventSettingKey: String { ShareDataKeys.eventSetting.rawValue }
    
    public func loadEventSetting() -> EventSettings {
        let setting = self.appSettingRepository.loadEventSetting()
        self.sharedDataStore.put(EventSettings.self, key: eventSettingKey, setting)
        return setting
    }
    
    public func changeEventSetting(_ params: EditEventSettingsParams) throws -> EventSettings {
        guard params.isValid
        else {
            throw RuntimeError("invalid edit parameters")
        }
        let newSetting = self.appSettingRepository.changeEventSetting(params)
        self.sharedDataStore.put(EventSettings.self, key: eventSettingKey, newSetting)
        return newSetting
    }
    
    public var currentEventSetting: AnyPublisher<EventSettings, Never> {
        return self.sharedDataStore
            .observe(EventSettings.self, key: self.eventSettingKey)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}


// MARK: - EventShareSettingUsecase

public protocol EventShareSettingUsecase: Sendable {

    func loadEventShareSetting() -> EventShareSettings
    func changeEventShareSetting(_ params: EditEventShareSettingsParams) throws -> EventShareSettings

    var currentEventShareSetting: AnyPublisher<EventShareSettings, Never> { get }
}

extension AppSettingUsecaseImple: EventShareSettingUsecase {

    private var eventShareSettingKey: String { ShareDataKeys.eventShareSetting.rawValue }

    public func loadEventShareSetting() -> EventShareSettings {
        let setting = self.appSettingRepository.loadEventShareSetting()
        self.sharedDataStore.put(EventShareSettings.self, key: eventShareSettingKey, setting)
        return setting
    }

    public func changeEventShareSetting(_ params: EditEventShareSettingsParams) throws -> EventShareSettings {
        guard params.isValid
        else {
            throw RuntimeError("invalid edit parameters")
        }
        let newSetting = self.appSettingRepository.changeEventShareSetting(params)
        self.sharedDataStore.put(EventShareSettings.self, key: eventShareSettingKey, newSetting)
        return newSetting
    }

    public var currentEventShareSetting: AnyPublisher<EventShareSettings, Never> {
        return self.sharedDataStore
            .observe(EventShareSettings.self, key: self.eventShareSettingKey)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
