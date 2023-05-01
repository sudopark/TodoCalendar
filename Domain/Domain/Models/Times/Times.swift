//
//  Times.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public enum DayOfWeeks: Int {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public enum Months: Int {
    case january = 1
    case february
    case march
    case april
    case may
    case june
    case july
    case august
    case september
    case october
    case november
    case december
}

public enum WeekOrdinal {
    case seq(Int)
    case last
}

public struct TimeStamp: Comparable {
    
    public let utcTimeInterval: TimeInterval
    public let timeZoneAbbreviation: String
    
    public init(_ utcTimeInterval: TimeInterval,
                timeZone abbreviation: String) {
        self.utcTimeInterval = utcTimeInterval
        self.timeZoneAbbreviation = abbreviation
    }
    
        public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.utcTimeInterval < rhs.utcTimeInterval
    }
    
    public func add(_ time: TimeInterval) -> TimeStamp {
        return .init(self.utcTimeInterval + time,
                     timeZone: self.timeZoneAbbreviation)
    }
}


extension TimeInterval {
    
    static func days(_ number: Int) -> TimeInterval {
        return TimeInterval(number) * .hours(24)
    }
    
    static func hours(_ number: Int) -> TimeInterval {
        return TimeInterval(number) * 3600
    }
}
