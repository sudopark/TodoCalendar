//
//  CalendarUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/06/21.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


public protocol CalendarUsecase {
    
    var currentDay: AnyPublisher<CalendarComponent.Day, Never> { get }
    
    func components(
        for month: Int, of year: Int
    ) -> AnyPublisher<CalendarComponent, Never>
    
    func getComponents(
        _ year: Int,
        _ month: Int,
        _ startDayOfWeek: DayOfWeeks
    ) throws -> CalendarComponent
}


public final class CalendarUsecaseImple: CalendarUsecase {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let holidayUsecase: any HolidayUsecase
    
    public init(
        calendarSettingUsecase: any CalendarSettingUsecase,
        holidayUsecase: any HolidayUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.holidayUsecase = holidayUsecase
    }
}

extension CalendarUsecaseImple {
    
    public var currentDay: AnyPublisher<CalendarComponent.Day, Never> {
        
        let currentTime = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
            .map { _ in Date() }
            .prepend(Date())
        let currentTimeZone = self.calendarSettingUsecase.currentTimeZone
        let transform: (Date, TimeZone) -> CalendarComponent.Day = { current, timeZone in
            let calendar = Calendar(identifier: .gregorian)
                |> \.timeZone .~ timeZone
            return .init(current, calendar: calendar)
        }
        
        return Publishers.CombineLatest(currentTime, currentTimeZone)
            .map(transform)
            .eraseToAnyPublisher()
    }
}

extension CalendarUsecaseImple {
    
    public func components(
        for month: Int, of year: Int
    ) -> AnyPublisher<CalendarComponent, Never> {
        
        let baseComponents = self.baseCalendarComponents(year, month)
        let holidaysGivenYear = self.holidayUsecase.holidays().map { $0[year] ?? [] }
        return Publishers.CombineLatest(baseComponents, holidaysGivenYear)
            .map { $0.update(holidays: $1)}
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    private func baseCalendarComponents(
        _ year: Int, _ month: Int
    ) -> AnyPublisher<CalendarComponent, Never> {
        return self.calendarSettingUsecase.firstWeekDay
            .compactMap { [weak self] firstDay -> CalendarComponent? in
                return try? self?.getComponents(year, month, firstDay)
            }
            .eraseToAnyPublisher()
    }
    
    public func getComponents(
        _ year: Int,
        _ month: Int,
        _ startDayOfWeek: DayOfWeeks
    ) throws -> CalendarComponent {
        
        let utcTimeZone = try TimeZone(abbreviation: "UTC").unwrap()
        let calendar = Calendar(identifier: .gregorian)
            |> \.timeZone .~ utcTimeZone
            |> \.firstWeekday .~ startDayOfWeek.rawValue
        
        let startDateOfMonth = try calendar.startDateOfMonth(year, month).unwrap()
        let lastDateOfMonth = try calendar.lastDayOfMonth(from: startDateOfMonth).unwrap()
        
        let calendarFirstDate = try calendar.firstDateOfWeek(startDayOfWeek, startDateOfMonth).unwrap()
        let calendarLastDate = try calendar.lastDateOfWeek(startDayOfWeek, lastDateOfMonth).unwrap()
        
        let daysInterval = calendarLastDate.timeIntervalSince(calendarFirstDate)
            |> { $0 / (3600 * 24) }
            |> Int.init
        let weeksInterval = daysInterval % 7 == 0 ? daysInterval / 7 : (daysInterval / 7) + 1
        
        let weeks: [CalendarComponent.Week] = try (0..<weeksInterval).map { weekOffset in
            let weekStart = try calendar.addDays(7 * weekOffset, from: calendarFirstDate).unwrap()
            let days: [CalendarComponent.Day] = try (0..<7).map { offset in
                let date = try calendar.addDays(offset, from: weekStart).unwrap()
                return .init(date, calendar: calendar)
            }
            return .init(days: days)
        }
        
        return .init(year: year, month: month, weeks: weeks)
    }
}


extension Calendar {
    
    func startDateOfMonth(_ year: Int, _ month: Int) -> Date? {
        let components = DateComponents()
            |> \.timeZone .~ self.timeZone
            |> \.year .~ pure(year)
            |> \.month .~ pure(month)
            |> \.day .~ 1
        return self.date(from: components)
            .map { self.startOfDay(for: $0) }
    }
    
    public func firstDateOfWeek(_ startDayOfWeek: DayOfWeeks, _ from: Date) -> Date? {
        let weekDay = self.component(.weekday, from: from)
        let daysToMinus = (weekDay - startDayOfWeek.rawValue + 7) % 7
        return self.addDays(-daysToMinus, from: from)
    }
    
    func lastDateOfWeek(_ startDayOfWeek: DayOfWeeks, _ from: Date) -> Date? {
        return self.firstDateOfWeek(startDayOfWeek, from)?.add(days: 6)
    }
}
