//
//  CalendarSettingUsecase.swift
//  CalendarDomainInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
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
    
    // manage dday count option
    func updateDDayCountsTargetDayAsOne(_ newValue: Bool)
    var ddayCountsTargetDayAsOne: AnyPublisher<Bool, Never> { get }
}
