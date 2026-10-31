//
//  StubCalendarSetingRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 5/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

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
    
    private var ddayCountsTargetDayAsOneStub: Bool?
    open func loadDDayCountsTargetDayAsOne() -> Bool? {
        return self.ddayCountsTargetDayAsOneStub
    }
    
    open func saveDDayCountsTargetDayAsOne(_ newValue: Bool) {
        self.ddayCountsTargetDayAsOneStub = newValue
    }
}
