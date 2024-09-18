//
//  CalendarSettingRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/06/03.
//

import Foundation


public protocol CalendarSettingRepository: AnyObject, Sendable {
    
    func saveTimeZone(_ timeZone: TimeZone)
    func loadUserSelectedTImeZone() -> TimeZone?
    
    func firstWeekDay() -> DayOfWeeks?
    func saveFirstWeekDay(_ newValue: DayOfWeeks)
}
