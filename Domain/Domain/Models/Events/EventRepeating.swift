//
//  EventRepeating.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Extensions


// MARK: - event repeating

public protocol EventRepeatingOption: Sendable {
    
    var compareHash: Int { get }
}

extension EventRepeatingOption where Self: Hashable {
    
    public var compareHash: Int {
        return self.hashValue
    }
}

public enum EventRepeatingOptions {
    
    public struct EveryDay: EventRepeatingOption, Hashable {
        public var interval: Int = 1   // 1 ~ 999
        public init() { }
    }
    
    public struct EveryWeek: EventRepeatingOption, Hashable {
        public var interval: Int = 1   // 1 ~ 5
        public var dayOfWeeks: [DayOfWeeks] = []
        public var timeZone: TimeZone
        
        public init(_ timeZone: TimeZone) {
            self.timeZone = timeZone
        }
    }
    
    public struct EveryMonth: EventRepeatingOption, Hashable {
        
        public enum DateSelector: Hashable, Equatable, Sendable {
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
    
    public struct EveryYear: EventRepeatingOption, Hashable {
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

public struct EventRepeating: Equatable {
    
    public let repeatingStartTime: TimeInterval
    public var repeatOption: any EventRepeatingOption
    public var repeatingEndTime: TimeInterval?

    public init(repeatingStartTime: TimeInterval,
                repeatOption: any EventRepeatingOption) {
        self.repeatingStartTime = repeatingStartTime
        self.repeatOption = repeatOption
    }
    
    public func startTime(for eventTime: EventTime) -> TimeInterval {
        switch eventTime {
        case .allDay(_, let secondsFromGMT): return repeatingStartTime.earlistTimeZoneInterval(secondsFromGMT)
        default: return self.repeatingStartTime
        }
    }
    
    public func endTime(for eventTime: EventTime) -> TimeInterval? {
        switch eventTime {
        case .allDay(_, let secondsFromGMT):
            return self.repeatingEndTime.map { $0.latestTimeZoneInterval(secondsFromGMT) }
        default: return self.repeatingEndTime
        }
    }
    
    func isOverlap(with period: Range<TimeInterval>, for eventTime: EventTime) -> Bool {
        let closedPeriod = (period.lowerBound...period.upperBound+1)
        if let repeatingEndTime = self.endTime(for: eventTime) {
            return (self.startTime(for: eventTime)...repeatingEndTime).overlaps(closedPeriod)
        } else {
            return self.startTime(for: eventTime) < period.upperBound
        }
    }
    
    public static func == (lhs: EventRepeating, rhs: EventRepeating) -> Bool {
        return lhs.repeatingStartTime == rhs.repeatingStartTime
            && lhs.repeatOption.compareHash == rhs.repeatOption.compareHash
            && lhs.repeatingEndTime == rhs.repeatingEndTime
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
