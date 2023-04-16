//
//  EventRepeating.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Extensions


// MARK: - event repeating

public protocol EventRepeatingOption {
    
    func nextEventTime(from currentEventTime: EventTime) -> EventTime?
}

public enum EventRepeatingOptions {
    
    public struct EveryDay: EventRepeatingOption {
        public var interval: Int = 1   // 1 ~ 999
        public init() { }
        
        public func nextEventTime(from currentEventTime: EventTime) -> EventTime? {
            let currentLowerBoundDate = Date(timeIntervalSince1970: currentEventTime.lowerBound)
            guard let futureDate = currentLowerBoundDate.add(days: self.interval)
            else { return nil }
            let interval = futureDate.timeIntervalSince(currentLowerBoundDate)
            return currentEventTime.shift(interval)
        }
    }
    
    public struct EveryWeek: EventRepeatingOption {
        public var interval: Int = 1   // 1 ~ 5
        public var dayOfWeeks: [DayOfWeeks] = []
        public var timeZone: TimeZone
        
        public init(_ timeZone: TimeZone) {
            self.timeZone = timeZone
        }
        
        // 유저가 kst에서 2001-1월 1일 하루종일을 만듬 -> utc offset: 0
        // utc offset은 다 동일하다
        // utc로 타임존을 설정하고 0을 date로 변환하면 -> 날짜는 1월 1일이 나옴
        // pdt로 타임존을 설정하면 0을 date로 변환하면 -> 날짜는 2000년 12월 31일이 나옴
        public func nextEventTime(from currentEventTime: EventTime) -> EventTime? {
            let currentLowerBoundDate = Date(timeIntervalSince1970: currentEventTime.lowerBound)
            guard let futureDate = self.nextEventLowerBoundDate(currentLowerBoundDate)
            else { return nil }
            let interval = futureDate.timeIntervalSince(currentLowerBoundDate)
            return currentEventTime.shift(interval)
        }
        
        private func nextEventLowerBoundDate(_ currentLowerBoundDate: Date) -> Date? {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = self.timeZone
            guard let currentEventWeekDay = calendar.dateComponents([.weekday], from: currentLowerBoundDate).weekday
            else { return nil }
            
            if let nextDayOfWeekWithSameWeek = self.dayOfWeeks.next(currentEventWeekDay) {
                let intervalDays = nextDayOfWeekWithSameWeek.rawValue - currentEventWeekDay
                return currentLowerBoundDate.add(days: intervalDays)
            } else {
                return currentLowerBoundDate.add(days: self.interval * 7)
                
            }
        }
    }
    
    public struct EveryMonth: EventRepeatingOption {
        
        public var interval: Int = 1   // 1 ~ 11
        public var weekSeqs: [WeekSeq] = []
        public var weekOfDays: [DayOfWeeks] = []
        public let timeZone: TimeZone
        
        public init(timeZone: TimeZone) {
            self.timeZone = timeZone
        }
        
        public func nextEventTime(from currentEventTime: EventTime) -> EventTime? {
            let currentLowerBoundDate = Date(timeIntervalSince1970: currentEventTime.lowerBound)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = self.timeZone
            let components = calendar.dateComponents([.month, .weekday], from: currentLowerBoundDate)
            guard let month = components.month, let weekDay = components.weekday
            else { return nil }
            
            guard let nextEventLowerBound = self.sameWeekNextEventLowerBound(
                calendar, current: weekDay, month: month, currentLowerBoundDate
            )
            ?? (self.nextWeekOrMonthEventLowerbound(
                calendar, current: weekDay, month, currentLowerBoundDate))
            else {
                return nil
            }
            let interval = nextEventLowerBound.timeIntervalSince(currentLowerBoundDate)
            return currentEventTime.shift(interval)
        }
        
        private func sameWeekNextEventLowerBound(
            _ calendar: Calendar,
            current weekDay: Int,
            month: Int,
            _ date: Date
        ) -> Date? {
            guard let sameWeekNextDay = self.weekOfDays.next(weekDay)
            else { return nil }
            guard let nextDate = date.add(days: sameWeekNextDay.rawValue - weekDay) else { return nil }
            let isSameMonth = calendar.dateComponents([.month], from: nextDate).month == month
            return isSameMonth ? nextDate : nil
        }
        
        private func nextWeekOrMonthEventLowerbound(_ calendar: Calendar,
                                                    current weekDay: Int,
                                                    _ month: Int,
                                                    _ date: Date) -> Date? {
            
            guard let currentWeekFirstRepeatingWeekDay = self.weekOfDays.first
                .flatMap ({ date.add(days: $0.rawValue - weekDay) })
            else { return nil }
            
            
            func nextWeekEventLowerBound() -> Date? {
                return self.weekSeqs.next(calendar, from: currentWeekFirstRepeatingWeekDay)
            }
            
            func nextMonthEventLowerBound() -> Date? {
                // 다음차수 달의 첫번째 반복 요일 -> 1주차에 해당하는 날짜를 구하고
                guard let addMonthDate = calendar.addMonth(self.interval, from: date),
                      let firstWeekDay = self.weekOfDays.first?.rawValue,
                      let nextMonthFirstWeekDay = calendar.first(day: firstWeekDay, from: addMonthDate),
                      let nextMonthFirstOrdinal = self.weekSeqs.first?.weekOrdinal(calendar, in: nextMonthFirstWeekDay),
                      let ordinalInterval = calendar.dateComponents([.weekdayOrdinal], from: nextMonthFirstWeekDay).weekdayOrdinal.map ({ nextMonthFirstOrdinal - $0 })
                else { return nil }
                
                // 첫번째 반복 주차와의 차이를 구해 x 7일 해서 더하고
                // 같은 달인지만 검사
                guard let nextDate = calendar.addDays(ordinalInterval * 7, from: nextMonthFirstWeekDay)
                else { return nil }
                let isSameMonth = calendar.dateComponents([.month], from: nextDate).month
                == calendar.dateComponents([.month], from: nextMonthFirstWeekDay).month
                return isSameMonth ? nextDate : nil
            }
            
            let next = nextWeekEventLowerBound()
            if next.flatMap({ calendar.dateComponents([.month], from: $0).month }) == month {
                return next
            } else {
                return nextMonthEventLowerBound()
            }
        }
    }
    
    public struct EveryYear: EventRepeatingOption {
        public var interval: Int = 1    // 1 ~ 99
        public var months: [Months] = []
        public var weekSeqs: [WeekSeq] = []
        public var dayOfWeek: [DayOfWeeks] = []
        public init() {}
        
        public func nextEventTime(from currentEventTime: EventTime) -> EventTime? {
            // TODO:
            return currentEventTime
        }
    }
}

public struct EventRepeating {

    public let repeatingStartTime: TimeStamp
    public var repeatOption: EventRepeatingOption
    public var repeatingEndTime: TimeStamp?

    public init(repeatingStartTime: TimeStamp,
                repeatOption: EventRepeatingOption) {
        self.repeatingStartTime = repeatingStartTime
        self.repeatOption = repeatOption
    }
}

extension EventRepeating {
    
    public func nextEventTime(from currentEventTime: EventTime) -> EventTime? {
        guard let nextTime = self.repeatOption.nextEventTime(from: currentEventTime)
        else { return nil }
        
        // https://github.com/sudopark/TodoCalendar/issues/9
        // 종료 시간과의 범위 비교시에는 fixedTimeZoneOffset 정보가 들어가야함
        // .atTime, .period는 utc 시간으로만 계산해도됨
        // .allDay는 종료시간의 timeStamp에도 fixedTimeZoneOffset이 포함되어야함
        if let endTime = self.repeatingEndTime, nextTime.upperBound > endTime.utcTimeInterval {
            return nil
        }
        return nextTime
    }
}


private extension Array where Element == DayOfWeeks {
    
    func next(_ currentDayOfWeek: Int) -> DayOfWeeks? {
        return self.first(where: { $0.rawValue > currentDayOfWeek })
    }
}

private extension Array where Element == WeekSeq {
    
    func next(_ calendar: Calendar, from date: Date) -> Date? {
        guard let ordinal = calendar.dateComponents([.weekdayOrdinal], from: date).weekdayOrdinal
        else { return nil }
        for seq in self {
            if let next = seq.next(calendar, current: ordinal, date) {
                return next
            }
        }
        return nil
    }
}

private extension WeekSeq {
    
    func next(_ calendar: Calendar, current ordinal: Int, _ date: Date) -> Date? {
        
        switch self {
        case .seq(let weekOrdinal) where ordinal < weekOrdinal :
            let weekInterval = weekOrdinal - ordinal
            return date.add(days: weekInterval * 7)
            
        case .last:
            guard let lastSameWeekDay = calendar.lastOfSameWeekDay(date) else { return nil }
            return lastSameWeekDay > date ? lastSameWeekDay : nil
            
        default: return nil
        }
    }
    
    func weekOrdinal(_ calendar: Calendar, in date: Date) -> Int? {
        switch self {
        case .seq(let ordinal): return ordinal
        case .last:
            guard let lastSameWeekDay = calendar.lastOfSameWeekDay(date) else { return nil }
            return calendar.dateComponents([.weekdayOrdinal], from: lastSameWeekDay).weekdayOrdinal
        }
    }
}
