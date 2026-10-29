//
//  StubCalendarSetingRepository.swift
//  CalendarRepositoryTesting
//
//  Created by sudo.park on 5/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import CalendarDomainInterface
import CalendarRepositoryInterface

open class StubCalendarSettingRepository: CalendarSettingRepository, @unchecked Sendable {
    
    public init() { }
    
    private var selectedTimeZone: TimeZone?
    open func saveTimeZone(_ timeZone: TimeZone) {
        self.selectedTimeZone = timeZone
    }
    
    open func loadUserSelectedTImeZone() -> TimeZone? {
        return self.selectedTimeZone
    }
    
    private var firstWeekDayStub: DayOfWeeks?
    open func firstWeekDay() -> DayOfWeeks? {
        return self.firstWeekDayStub
    }
    
    open func saveFirstWeekDay(_ newValue: DayOfWeeks) {
        self.firstWeekDayStub = newValue
    }
}
