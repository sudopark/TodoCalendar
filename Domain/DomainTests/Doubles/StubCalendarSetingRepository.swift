//
//  StubCalendarSetingRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/03.
//

import Foundation
import Domain

final class StubCalendarSetingRepository: CalendarSettingRepository, @unchecked Sendable {
    
    private var selectedTimeZone: TimeZone?
    func saveTimeZone(_ timeZone: TimeZone) {
        self.selectedTimeZone = timeZone
    }
    
    func loadUserSelectedTImeZone() -> TimeZone? {
        return self.selectedTimeZone
    }
    
    private var firstWeekDayStub: DayOfWeeks?
    func firstWeekDay() -> DayOfWeeks? {
        return self.firstWeekDayStub
    }
    
    func saveFirstWeekDay(_ newValue: DayOfWeeks) {
        self.firstWeekDayStub = newValue
    }
}
