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
    
    public let timeInterval: TimeInterval
    public let secondsFromGMT: TimeInterval
    
    public init(timeInterval: TimeInterval, secondsFromGMT: TimeInterval) {
        self.timeInterval = timeInterval
        self.secondsFromGMT = secondsFromGMT
    }
    
    public var timeIntervalWithUTCOffset: TimeInterval { self.timeInterval + self.secondsFromGMT }
    
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.timeInterval < rhs.timeInterval
    }
}
