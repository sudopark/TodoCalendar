//
//  EventRepeatTimeEnumerator.swift
//  Domain
//
//  Created by sudo.park on 2023/04/16.
//

import Foundation
import Prelude
import Optics

final class EventRepeatTimeEnumerator {
    
    private let calendar: Calendar
    private let option: EventRepeatingOption
    
    init?(_ option: EventRepeatingOption) {
        switch option {
        case is EventRepeatingOptions.EveryDay:
            self.calendar = Calendar(identifier: .gregorian)
            self.option = option
            
        case let everyWeek as EventRepeatingOptions.EveryWeek:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = everyWeek.timeZone
            self.calendar = calendar
            self.option = option
            
        case let everyMonth as EventRepeatingOptions.EveryMonth:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = everyMonth.timeZone
            self.calendar = calendar
            self.option = option
            
        case let everyYear as EventRepeatingOptions.EveryYear:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = everyYear.timeZone
            self.calendar = calendar
            self.option = option
            
        default: return nil
        }
    }
    
    private struct Current {
        
        let year: Int
        let month: Int
        let day: Int
        let ordinal: Int
        let weekDay: Int
        let date: Date
        let hour: Int
        let minute: Int
        let second: Int
        
        init?(_ calendar: Calendar, date: Date) {
            var components = calendar.dateComponents([.year, .month, .day, .weekdayOrdinal, .weekday, .hour, .minute, .second], from: date)
            components.timeZone = calendar.timeZone
            guard let year = components.year,
                  let month = components.month,
                  let day = components.day,
                  let ordinal = components.weekdayOrdinal,
                  let weekDay = components.weekday,
                  let hour = components.hour,
                  let minute = components.minute,
                  let second = components.second
            else { return nil }
            self.year = year
            self.month = month
            self.day = day
            self.ordinal = ordinal
            self.weekDay = weekDay
            self.date = date
            self.hour = hour
            self.minute = minute
            self.second = second
        }
    }
    
    func nextEventTime(from time: EventTime, until endTime: TimeStamp?) -> EventTime? {
        let currentEventStartDate = Date(timeIntervalSince1970: time.lowerBound)
        guard let current = Current(self.calendar, date: currentEventStartDate) else { return nil }
        let nextDate: Date?
        switch self.option {
        case let everyDay as EventRepeatingOptions.EveryDay:
            nextDate = self.calendar.addDays(everyDay.interval, from: currentEventStartDate)
            
        case let everyWeek as EventRepeatingOptions.EveryWeek:
            nextDate = self.nextEventDate(everyWeek: everyWeek, current: current)
        case let everyMonth as EventRepeatingOptions.EveryMonth:
            nextDate = self.nextEventDate(everyMonth: everyMonth, current: current, from: currentEventStartDate)
        case let everyYear as EventRepeatingOptions.EveryYear:
            nextDate = self.nextEventDate(everyYear, current)
        default: nextDate = nil
        }
        
        guard let interval = nextDate.map ({ $0.timeIntervalSince(currentEventStartDate) })
        else { return nil }
        
        let nextTime = time.shift(interval)
        if let endTime, nextTime.upperBound > endTime.utcTimeInterval {
            return nil
        }
        return nextTime
    }
}

// MARK: - next date by repeating options

extension EventRepeatTimeEnumerator {
    
    private func nextEventDate(
        everyWeek: EventRepeatingOptions.EveryWeek,
        current: Current
    ) -> Date? {
        
        func findEventTimeOnNextWeekFirstRepeatingDay() -> Date? {
            return everyWeek.dayOfWeeks.first
                .flatMap { self.calendar.addDays($0.rawValue - current.weekDay, from: current.date) }
                .flatMap { $0.add(days: everyWeek.interval * 7) }
        }
        return self.findEventDateOnSameWeek(everyWeek.dayOfWeeks, current: current)
            ?? findEventTimeOnNextWeekFirstRepeatingDay()
    }
    
    private func nextEventDate(
        everyMonth: EventRepeatingOptions.EveryMonth,
        current: Current,
        from date: Date
    ) -> Date? {
        
        let shouldSameMonth: (Date?) -> Bool = { nextDate in
            return nextDate.map { self.calendar.month(of: $0) } == current.month
        }
        
        switch everyMonth.selection {
        case .week(let ordinals, let weekDays):
            return self.findEventDateOnSameWeek(weekDays, current: current, shouldSameMonth)
            ?? self.findEventDateOnNextWeekFirstRepeatingDay(ordinals, weekDays, current: current, shouldSameMonth)
            ?? self.findEventDateOnNextMonthFirstRepeatingWeekAndDay(everyMonth.interval, repeatingOrdinals: ordinals, repeatingWeekDays: weekDays, current: current)
        case .days(let days):
            return self.findEventDateOnSameMonth(days, current)
            ?? self.findEventDateOnNextMonthFirstReaptingDay(everyMonth.interval, days, current)
        }
    }
    
    private func nextEventDate(
        _ everyYear: EventRepeatingOptions.EveryYear,
        _ current: Current
    ) -> Date? {
        
        let checkIsSameYear: (Date?) -> Bool = { next in
            return next.map { self.calendar.year(of: $0) } == current.year
        }

        return
            self.findEventDateOnSameWeek(everyYear.dayOfWeek, current: current, checkIsSameYear)
            
            ?? self.findEventDateOnNextWeekFirstRepeatingDay(
                everyYear.weekOrdinals,
                everyYear.dayOfWeek,
                current: current
            ) {
                $0.map { self.calendar.month(of: $0) } == current.month
                && checkIsSameYear($0)
            }
            
            ?? everyYear.nextMonthInterval(from: current.month)
                .flatMap { interval in
                    self.findEventDateOnNextMonthFirstRepeatingWeekAndDay(
                        interval,
                        repeatingOrdinals: everyYear.weekOrdinals,
                        repeatingWeekDays: everyYear.dayOfWeek,
                        current: current,
                        checkIsSameYear
                    )
                }
            
            ?? self.findEventDateOnNextYearFirstRepeatingMonthWeekAndDay(
                interval: everyYear.interval,
                months: everyYear.months,
                ordinals: everyYear.weekOrdinals,
                weekDays: everyYear.dayOfWeek,
                current: current
            )
    }
}


// MARK: - finding methods

private extension EventRepeatTimeEnumerator {
    
    private func findEventDateOnSameWeek(
        _ repeatingWeekDays: [DayOfWeeks],
        current: Current,
        _ validator: (Date?) -> Bool = { $0 != nil }
    ) -> Date? {
        
        return repeatingWeekDays.next(current.weekDay)
            .flatMap { calendar.addDays($0.rawValue - current.weekDay, from: current.date) }
            .flatMap { validator($0) ? $0 : nil }
    }
    
    private func findEventDateOnNextWeekFirstRepeatingDay(
        _ repeatingOrdinals: [WeekOrdinal],
        _ repeatingWeekDays: [DayOfWeeks],
        current: Current,
        _ validator: (Date?) -> Bool = { $0 != nil }
    ) -> Date? {
        
        return repeatingWeekDays.first
            .flatMap { calendar.addDays($0.rawValue - current.weekDay, from: current.date) }
            .flatMap { repeatingOrdinals.next(self.calendar, from: $0) }
            .flatMap { validator($0) ? $0 : nil }
    }
    
    private func findEventDateOnNextMonthFirstRepeatingWeekAndDay(
        _ interval: Int,
        repeatingOrdinals: [WeekOrdinal],
        repeatingWeekDays: [DayOfWeeks],
        current: Current,
        _ validator: (Date?) -> Bool = { $0 != nil }
    ) -> Date? {
        
        guard let nextMonth = calendar.addMonth(interval, from: current.date)
        else { return nil }
        
        return calendar.addMonth(interval, from: current.date)
            .flatMap {
                self.findFirstOrdinalAndWeekDay(repeatingOrdinals.first, repeatingWeekDays.first, on: $0)
            }
            .flatMap {
                calendar.month(of: $0) == calendar.month(of: nextMonth) ? $0 : nil
            }
            .flatMap { validator($0) ? $0 : nil }
    }
    
    private func findFirstOrdinalAndWeekDay(
        _ ordinal: WeekOrdinal?,
        _ weekday: DayOfWeeks?,
        on monthDate: Date
    ) -> Date? {
        guard let firstWeekOfGivenWeekDay = weekday.flatMap ({ calendar.first(day: $0.rawValue, from: monthDate) }),
            let firstWeekOfGivenWeekDayOrdinal = calendar.dateComponents([.weekdayOrdinal], from: firstWeekOfGivenWeekDay).weekdayOrdinal,
            let ordinalAtMonth = ordinal.flatMap ({ $0.weekOrdinal(calendar, in: firstWeekOfGivenWeekDay) })
        else { return nil }
        
        let ordinalInterval = ordinalAtMonth - firstWeekOfGivenWeekDayOrdinal
        return calendar.addDays(ordinalInterval * 7, from: firstWeekOfGivenWeekDay)
    }
    
    private func findEventDateOnSameMonth(
        _ days: [Int],
        _ current: Current
    ) -> Date? {
        
        guard let nextDayOnSameMonth = days.nextDay(current.day) else { return nil }
        var components = self.calendar.dateComponents(in: self.calendar.timeZone, from: current.date)
        components.day = nextDayOnSameMonth
        
        let compareIsNotFloored: (Date) -> Date? = {
            return self.calendar.day(of: $0) == nextDayOnSameMonth ? $0 : nil
        }
        return self.calendar.date(from: components)
            .flatMap(compareIsNotFloored)
    }
    
    private func findEventDateOnNextMonthFirstReaptingDay(
        _ interval: Int,
        _ days: [Int],
        _ current: Current
    ) -> Date? {
        
        guard let firstRepeatDay = days.first else { return nil }
        return self.calendar.firstDayOfMonth(from: current.date)
            .flatMap { self.calendar.addMonth(interval, from: $0)}
            .flatMap { self.calendar.addDays(firstRepeatDay-1, from: $0) }
            .flatMap { self.calendar.syncTimes($0, with: current.date) }
    }
    
    private func findEventDateOnNextYearFirstRepeatingMonthWeekAndDay(
        interval: Int,
        months: [Months],
        ordinals: [WeekOrdinal],
        weekDays: [DayOfWeeks],
        current: Current
    ) -> Date? {
        
        guard let firstMonth = months.first,
              let firstOrdinal = ordinals.first,
              let firstWeekDay = weekDays.first,
              let nextYearFirstRepeatingMonth = self.calendar.addYear(interval, from: current.date)
                  .flatMap ({ calendar.dateBySetting(from: $0) { $0.month = firstMonth.rawValue } })
        else { return nil }
        
        return self.findFirstOrdinalAndWeekDay(firstOrdinal, firstWeekDay, on: nextYearFirstRepeatingMonth)
            .flatMap {
                calendar.month(of: $0) == calendar.month(of: nextYearFirstRepeatingMonth) ? $0 : nil
            }
            
    }
}

private extension Array where Element == Int {
    
    func nextDay(_ current: Int) -> Int? {
        return self.first(where: { $0 > current })
    }
}
