//
//  EventRepeating.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


// MARK: - event repeating

public protocol EventRepeatingOption { }

public enum EventRepeatingOptions {
    
    public struct EveryDay: EventRepeatingOption {
        public var interval: Int = 1   // 1 ~ 999
        public init() { }
    }
    
    public struct EveryWeek: EventRepeatingOption {
        public var interval: Int = 1   // 1 ~ 5
        public var dayOfWeeks: [DayOfWeeks] = []
        public init() { }
    }
    
    public struct EveryMonth: EventRepeatingOption {
        
        public var interval: Int = 1   // 1 ~ 11
        public var weekSeqs: [WeekSeq] = []
        public var weekOfDays: [DayOfWeeks] = []
        public init() { }
    }
    
    public struct EveryYear: EventRepeatingOption {
        public var interval: Int = 1    // 1 ~ 99
        public var months: [Months] = []
        public var weekSeqs: [WeekSeq] = []
        public var dayOfWeek: [DayOfWeeks] = []
        public init() {}
    }
}

public struct EventRepeating {

    public let repeatingStartTime: Date
    public var repeatOption: EventRepeatingOption
    public var repeatingEndTime: Date?

    public init(repeatingStartTime: Date,
                repeatOption: EventRepeatingOption) {
        self.repeatingStartTime = repeatingStartTime
        self.repeatOption = repeatOption
    }
}
