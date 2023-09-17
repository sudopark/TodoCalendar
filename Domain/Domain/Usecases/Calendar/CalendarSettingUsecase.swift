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
    
    func prepare()
    
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
    
    private let settingRepository: any CalendarSettingRepository
    private let shareDataStore: SharedDataStore
    
    public init(
        settingRepository: any CalendarSettingRepository,
        shareDataStore: SharedDataStore
    ) {
        self.settingRepository = settingRepository
        self.shareDataStore = shareDataStore
    }
}

// MARK: - prepare

extension CalendarSettingUsecaseImple {
    
    public func prepare() {
        
        let firstWeekDay = self.settingRepository.firstWeekDay() ?? .sunday
        self.shareDataStore.put(DayOfWeeks.self, key: ShareDataKeys.firstWeekDay.rawValue, firstWeekDay)
        
        let currentTimeZone = self.settingRepository.loadUserSelectedTImeZone() ?? TimeZone.current
        self.shareDataStore.put(TimeZone.self, key: ShareDataKeys.timeZone.rawValue, currentTimeZone)
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
        
        return self.shareDataStore
            .observe(DayOfWeeks.self, key: shareKey)
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
        
        return self.shareDataStore
            .observe(TimeZone.self, key: shareKey)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
