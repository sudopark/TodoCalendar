//
//  Times.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public enum DayOfWeeks {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public enum Months {
    case january
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

public enum WeekSeq {
    case seq(Int)
    case lastWeek
}

public struct TimeStamp: Comparable {
    
    public let utcTimeInterval: TimeInterval
    public let fixedGMTTImeZoneOffset: TimeInterval
    
    public var timeInterval: TimeInterval {
        return utcTimeInterval + fixedGMTTImeZoneOffset
    }
    
    public init(utcTimeInterval: TimeInterval, withFixed timeZoneOffset: TimeInterval = 0) {
        self.utcTimeInterval = utcTimeInterval
        self.fixedGMTTImeZoneOffset = timeZoneOffset
    }
    
        public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.timeInterval < rhs.timeInterval
    }
    
    public func add(_ time: TimeInterval) -> TimeStamp {
        return .init(
            utcTimeInterval: self.utcTimeInterval + time,
            withFixed: self.fixedGMTTImeZoneOffset
        )
    }
}


extension TimeInterval {
    
    static func days(_ number: Int) -> TimeInterval {
        return TimeInterval(number) * 24 * 3600
    }
}
