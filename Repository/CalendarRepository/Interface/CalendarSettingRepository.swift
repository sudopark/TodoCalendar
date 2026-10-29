//
//  CalendarSettingRepository.swift
//  CalendarRepositoryInterface
//
//  Created by sudo.park on 2023/06/03.
//

import Foundation
import CalendarDomainInterface


public protocol CalendarSettingRepository: AnyObject, Sendable {
    
    func saveTimeZone(_ timeZone: TimeZone)
    func loadUserSelectedTImeZone() -> TimeZone?
    
    func firstWeekDay() -> DayOfWeeks?
    func saveFirstWeekDay(_ newValue: DayOfWeeks)
}
