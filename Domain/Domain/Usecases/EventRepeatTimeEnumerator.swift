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
//            calendar.timeZone = everyYear.tim
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
            nextDate = nil
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

// MARK: - every week

extension EventRepeatTimeEnumerator {
    
    private func nextEventDate(
        everyWeek: EventRepeatingOptions.EveryWeek,
        current: Current
    ) -> Date? {
        
        if let nextDateOnSameWeek = self.findNextEventDateOnSameWeek(everyWeek.dayOfWeeks, current: current) {
            return nextDateOnSameWeek
        } else {
            return current.date.add(days: everyWeek.interval * 7)
        }
    }
    
    private func findNextEventDateOnSameWeek(
        _ repeatingWeekDays: [DayOfWeeks],
        current: Current,
        _ validator: (Date?) -> Bool = { $0 != nil }
    ) -> Date? {
        let nextDate = repeatingWeekDays.next(current.weekDay)
            .flatMap { calendar.addDays($0.rawValue - current.weekDay, from: current.date) }
        return validator(nextDate) ? nextDate : nil
    }
}


// MARK: - every month

extension EventRepeatTimeEnumerator {
    
    private func nextEventDate(
        everyMonth: EventRepeatingOptions.EveryMonth,
        current: Current,
        from date: Date
    ) -> Date? {
        
        switch everyMonth.selection {
        case .week(let ordinals, let weekDays):
            return self.findNextEventDateOnSameWeek(weekDays, current: current) {
                $0.map { self.calendar.month(of: $0) } == current.month
            }
            ?? self.findNextEventDateAfterWeek(ordinals, weekDays, current: current)
            ?? self.findNextEventDateAfterNextMonth(everyMonth.interval, repeatingOrdinals: ordinals, repeatingWeekDays: weekDays, current: current)
        case .days(let days):
            return self.findNextEventDateInSameMonth(days, current)
            ?? self.findNextEventDateInNextMonth(everyMonth.interval, days, current)
        }
    }
    
    private func findNextEventDateAfterWeek(
        _ repeatingOrdinals: [WeekOrdinal],
        _ repeatingWeekDays: [DayOfWeeks],
        current: Current,
        _ validator: (Date?) -> Bool = { $0 != nil }
    ) -> Date? {
        
        guard let firstRepeatingWeekDay = repeatingWeekDays.first,
              let sameWeekFirstRepeatingWeekDay = calendar.addDays(firstRepeatingWeekDay.rawValue - current.weekDay, from: current.date)
        else { return nil }
        let nextDate = repeatingOrdinals.next(self.calendar, from: sameWeekFirstRepeatingWeekDay)
        return validator(nextDate) ? nextDate : nil
    }
    
    private func findNextEventDateAfterNextMonth(
        _ interval: Int,
        repeatingOrdinals: [WeekOrdinal],
        repeatingWeekDays: [DayOfWeeks],
        current: Current,
        _ validator: (Date?) -> Bool = { $0 != nil }
    ) -> Date? {
        
        guard let nextMonth = calendar.addMonth(interval, from: current.date),
              let firstRepeatingWeekDay = repeatingWeekDays.first?.rawValue,
              let nextMonthFirstRepeatingWeekDay = calendar.first(day: firstRepeatingWeekDay, from: nextMonth),
              let nextMonthFirstRepeatingWeekDayOrdinal = calendar.dateComponents([.weekdayOrdinal], from: nextMonthFirstRepeatingWeekDay).weekdayOrdinal,
              let nextMonthFirstRepeatingOrdinal = repeatingOrdinals.first?.weekOrdinal(calendar, in: nextMonthFirstRepeatingWeekDay)
        else { return nil }
        
        let ordinalInterval = nextMonthFirstRepeatingOrdinal - nextMonthFirstRepeatingWeekDayOrdinal
     
        guard let nextDate = self.calendar.addDays(ordinalInterval * 7, from: nextMonthFirstRepeatingWeekDay)
        else { return nil }
        
        let isSameMonth = calendar.month(of: nextDate) == calendar.month(of: nextMonth)
        return isSameMonth ? nextDate : nil
    }
    
    private func findNextEventDateInSameMonth(
        _ days: [Int],
        _ current: Current
    ) -> Date? {
        
        guard let nextDayOnSameMonth = days.nextDay(current.day) else { return nil }
        let components = DateComponents(
            timeZone: self.calendar.timeZone,
            year: current.year,
            month: current.month,
            day: nextDayOnSameMonth,
            hour: current.hour,
            minute: current.minute,
            second: current.second
        )
        guard let next = calendar.date(from: components),
              self.calendar.day(of: next) == nextDayOnSameMonth
        else { return nil }
        return next
    }
    
    private func findNextEventDateInNextMonth(
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
}

// MARK: - every year


private extension Array where Element == Int {
    
    func nextDay(_ current: Int) -> Int? {
        return self.first(where: { $0 > current })
    }
}
