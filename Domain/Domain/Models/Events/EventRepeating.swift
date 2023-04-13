//
//  EventRepeating.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


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
        public init() { }
        
        public func nextEventTime(from currentEventTime: EventTime) -> EventTime? {
            return currentEventTime
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
        if let endTime = self.repeatingEndTime, nextTime.upperBound > endTime.timeInterval {
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
