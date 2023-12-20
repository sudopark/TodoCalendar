//
//  CalendarSettingRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/06/04.
//

import Foundation
import Domain


public final class CalendarSettingRepositoryImple: CalendarSettingRepository, Sendable {
    
    private let environmentStorage: any EnvironmentStorage
    
    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }
    
    private var timeZoneKey: String { "user_timeZone" }
    private var firstWeekDayKey: String { "first_week_day" }
}

extension CalendarSettingRepositoryImple {
    
    public func firstWeekDay() -> DayOfWeeks? {
        guard let rawValue: Int = self.environmentStorage.load(firstWeekDayKey)
        else { return nil }
        return .init(rawValue: rawValue)
    }
    
    public func saveFirstWeekDay(_ newValue: DayOfWeeks) {
        self.environmentStorage.update(self.firstWeekDayKey, newValue.rawValue)
    }
    
    public func loadUserSelectedTImeZone() -> TimeZone? {
        guard let identifier: String = self.environmentStorage.load(self.timeZoneKey)
        else { return nil }
        return TimeZone(identifier: identifier)
    }
    
    public func saveTimeZone(_ timeZone: TimeZone) {
        let identifier = timeZone.identifier
        self.environmentStorage.update(self.timeZoneKey, identifier)
    }
}
