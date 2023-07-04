//
//  StubCalendarSettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/06/26.
//

import Foundation
import Combine
import Domain


open class StubCalendarSettingUsecase: CalendarSettingUsecase {
    
    public init() { }
    
    open func prepare() {
        self.firstWeekDaySubject.send(.sunday)
        self.currentTimeZoneSubject.send(TimeZone(abbreviation: "KST")!)
    }
    
    private let firstWeekDaySubject = CurrentValueSubject<DayOfWeeks?, Never>(nil)
    open func updateFirstWeekDay(_ newValue: DayOfWeeks) {
        self.firstWeekDaySubject.send(newValue)
    }
    
    open var firstWeekDay: AnyPublisher<DayOfWeeks, Never> {
        return self.firstWeekDaySubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    open func loadAllTimeZones() -> [TimeZone] {
        return [
            TimeZone(abbreviation: "KST"),
            TimeZone(identifier: "Africa/Abidjan"),
            TimeZone(identifier: "America/Cayman"),
            TimeZone(identifier: "Pacific/Bougainville")
        ]
        .compactMap { $0 }
    }
    
    private let currentTimeZoneSubject = CurrentValueSubject<TimeZone?, Never>(nil)
    open func selectTimeZone(_ timeZone: TimeZone) {
        self.currentTimeZoneSubject.send(timeZone)
    }
    
    open var currentTimeZone: AnyPublisher<TimeZone, Never> {
        return self.currentTimeZoneSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
