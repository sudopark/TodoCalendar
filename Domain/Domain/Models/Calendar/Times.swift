//
//  Times.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public enum DayOfWeeks: Int, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    
    public var isWeekEnd: Bool {
        return self == .sunday || self == .saturday
    }
}

public enum Months: Int, Sendable {
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

public enum WeekOrdinal: Equatable, Hashable, Sendable {
    case seq(Int)
    case last
}

extension TimeInterval {
    
    static func days(_ number: Int) -> TimeInterval {
        return TimeInterval(number) * .hours(24)
    }
    
    static func hours(_ number: Int) -> TimeInterval {
        return TimeInterval(number) * 3600
    }
    
    public func earlistTimeZoneInterval(_ secondsFromGMT: TimeInterval) -> TimeInterval {
        return self + secondsFromGMT - .hours(14)
    }
    
    public func latestTimeZoneInterval(_ secondsFromGMT: TimeInterval) -> TimeInterval {
        return self + secondsFromGMT + .hours(12)
    }
}


extension TimeZone {
    
    public var addreviationKey: String? {
        return TimeZone.abbreviationDictionary
            .first(where: { $0.value == self.identifier })?.key
    }
}


extension Range where Bound == TimeInterval {
    
    func intervalRanges(secondsFromGMT: TimeInterval) -> Range<TimeInterval> {
        return self.lowerBound.earlistTimeZoneInterval(secondsFromGMT)
            ..<
        self.upperBound.latestTimeZoneInterval(secondsFromGMT)
    }
    
    public func shift(_ interval: TimeInterval) -> Range {
        return self.lowerBound+interval..<self.upperBound+interval
    }
}
