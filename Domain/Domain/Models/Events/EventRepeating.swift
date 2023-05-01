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
    
    
}

public enum EventRepeatingOptions {
    
    public struct EveryDay: EventRepeatingOption {
        public var interval: Int = 1   // 1 ~ 999
        public init() { }
    }
    
    public struct EveryWeek: EventRepeatingOption {
        public var interval: Int = 1   // 1 ~ 5
        public var dayOfWeeks: [DayOfWeeks] = []
        public var timeZone: TimeZone
        
        public init(_ timeZone: TimeZone) {
            self.timeZone = timeZone
        }
    }
    
    public struct EveryMonth: EventRepeatingOption {
        
        public enum DateSelector {
            case days([Int])    // days -> 1~31
            case week(_ ordinals: [WeekOrdinal], _ weekDays: [DayOfWeeks])
        }
        
        public var interval: Int = 1   // 1 ~ 11
        public var selection: DateSelector = .days([1])
        public let timeZone: TimeZone
        
        public init(timeZone: TimeZone) {
            self.timeZone = timeZone
        }
    }
    
    public struct EveryYear: EventRepeatingOption {
        public var interval: Int = 1    // 1 ~ 99
        public var months: [Months] = []
        public var weekOrdinals: [WeekOrdinal] = []
        public var dayOfWeek: [DayOfWeeks] = []
        public let timeZone: TimeZone
        
        public init(timeZone: TimeZone) {
            self.timeZone = timeZone
        }
        
        func nextMonthInterval(from currentMonth: Int) -> Int? {
            return self.months.first(where: { $0.rawValue > currentMonth })
                .map { $0.rawValue - currentMonth }
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
    
    func isClamped(with period: Range<TimeStamp>) -> Bool {
        let closedPeriod = (period.lowerBound...period.upperBound.add(1))
        if let repeatingEndTime {
            return (self.repeatingStartTime...repeatingEndTime)
                .clamped(to: closedPeriod).isEmpty == false
        } else {
            return self.repeatingStartTime < period.upperBound
        }
    }
}



extension Array where Element == DayOfWeeks {
    
    func next(_ currentDayOfWeek: Int) -> DayOfWeeks? {
        return self.first(where: { $0.rawValue > currentDayOfWeek })
    }
}

extension Array where Element == WeekOrdinal {
    
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

extension WeekOrdinal {
    
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
