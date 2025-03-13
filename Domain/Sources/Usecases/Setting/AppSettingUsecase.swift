//
//  AppSettingUsecase.swift
//  Domain
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


public final class AppSettingUsecaseImple: @unchecked Sendable {
    
    private let appSettingRepository: any AppSettingRepository
    private let viewAppearanceStore: any ViewAppearanceStore
    private let sharedDataStore: SharedDataStore
    
    public init(
        appSettingRepository: any AppSettingRepository,
        viewAppearanceStore: any ViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.appSettingRepository = appSettingRepository
        self.viewAppearanceStore = viewAppearanceStore
        self.sharedDataStore = sharedDataStore
    }
}

// MARK: - appearance

extension AppSettingUsecaseImple: UISettingUsecase {
    
    private var calednarSettingKey: String { ShareDataKeys.calendarAppearance.rawValue }
    private var defaultEventTagColorKey: String { ShareDataKeys.defaultEventTagColor.rawValue }
    
    public func loadSavedAppearanceSetting() -> AppearanceSettings {
        let setting = self.appSettingRepository.loadSavedViewAppearance()
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
        // TODO: 추후 커스텀 테마도 지원하도록 확장할 예정
        return [.systemTheme, .defaultLight, .defaultDark]
    }
    
    public func applyEventTagColors(_ tags: [any EventTag]) {
        self.viewAppearanceStore.applyEventTagColors(tags)
    }
    
    public func refreshAppearanceSetting() async throws -> AppearanceSettings {
        let setting = try await self.appSettingRepository.refreshAppearanceSetting()
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
        let newSetting = try self.appSettingRepository.changeCalendarAppearanceSetting(params)
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
