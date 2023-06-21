//
//  CalendarSettingUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/06/03.
//

import Foundation
import Combine


// MARK: - CalendarSettingUsecase

public protocol CalendarSettingUsecase {
    
    // manage first day of week
    func updateFirstWeekDay(_ newValue: DayOfWeeks)
    var firstWeekDay: AnyPublisher<DayOfWeeks, Never> { get }
    
    // manage timeZones
    func loadAllTimeZones() -> [TimeZone]
    func selectTimeZone(_ timeZone: TimeZone)
    var currentTimeZone: AnyPublisher<TimeZone, Never> { get }
}


// MARK: - CalendarSettingUsecaseImple

public final class CalendarSettingUsecaseImple: CalendarSettingUsecase {
    
    private let settingRepository: CalendarSettingRepository
    private let shareDataStore: SharedDataStore
    
    public init(
        settingRepository: CalendarSettingRepository,
        shareDataStore: SharedDataStore
    ) {
        self.settingRepository = settingRepository
        self.shareDataStore = shareDataStore
    }
}

// MARK: - manage first week day

extension CalendarSettingUsecaseImple {
    
    public func updateFirstWeekDay(_ newValue: DayOfWeeks) {
        self.settingRepository.saveFirstWeekDay(newValue)
        self.shareDataStore.put(
            DayOfWeeks.self,
            key: ShareDataKeys.firstWeekDay.rawValue,
            newValue
        )
    }
    
    public var firstWeekDay: AnyPublisher<DayOfWeeks, Never> {
        
        let shareKey = ShareDataKeys.firstWeekDay.rawValue
        let setupSavedFirstWeekDay: (Subscription) -> Void = { [weak self] _ in
            guard let self = self else { return }
            let value = self.settingRepository.firstWeekDay() ?? .sunday
            self.shareDataStore.put(DayOfWeeks.self, key: shareKey, value)
        }
        
        return self.shareDataStore
            .observe(DayOfWeeks.self, key: shareKey)
            .handleEvents(receiveSubscription: setupSavedFirstWeekDay)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}


// MARK: - Manage timeZone

extension CalendarSettingUsecaseImple {
    
    public func loadAllTimeZones() -> [TimeZone] {
        let timeZoneIdentifiers = TimeZone.knownTimeZoneIdentifiers
        return timeZoneIdentifiers.compactMap { TimeZone(identifier: $0) }
    }
    
    public func selectTimeZone(_ timeZone: TimeZone) {
        self.settingRepository.saveTimeZone(timeZone)
        let shareKey = ShareDataKeys.timeZone.rawValue
        self.shareDataStore.update(TimeZone.self, key: shareKey) { _ in timeZone }
    }
    
    public var currentTimeZone: AnyPublisher<TimeZone, Never> {
        let shareKey = ShareDataKeys.timeZone.rawValue
        
        let setupSavedTimeZone: (Subscription) -> Void = { [weak self] _ in
            guard let savedTimezone = self?.settingRepository.loadUserSelectedTImeZone()
            else { return }
            self?.shareDataStore.update(TimeZone.self, key: shareKey) { _ in savedTimezone }
        }
        
        return self.shareDataStore
            .observe(TimeZone.self, key: shareKey)
            .map { $0 ?? TimeZone.current }
            .handleEvents(receiveSubscription: setupSavedTimeZone)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
