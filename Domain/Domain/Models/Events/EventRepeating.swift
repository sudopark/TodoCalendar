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
            var addingComponents = DateComponents()
            addingComponents.day = interval
            guard let futureDate = Calendar(identifier: .gregorian).date(byAdding: addingComponents, to: currentLowerBoundDate)
            else { return nil }
            let interval = futureDate.timeIntervalSince(currentLowerBoundDate)
            return currentEventTime.shift(interval)
        }
    }
    
    public struct EveryWeek: EventRepeatingOption {
        public var interval: Int = 1   // 1 ~ 5
        public var dayOfWeeks: [DayOfWeeks] = []
        public init() { }
        
        public func nextEventTime(from currentEventTime: EventTime) -> EventTime? {
            // TODO:
            return currentEventTime
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
        
        if let endTime = self.repeatingEndTime, nextTime.upperBound > endTime.timeInterval {
            return nil
        }
        return nextTime
    }
}
