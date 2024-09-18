//
//  Times.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation
import Extensions

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
    
    public var text: String {
        switch self {
        case .sunday: return "dayname::sunday".localized()
        case .monday: return "dayname::monday".localized()
        case .tuesday: return "dayname::tuesday".localized()
        case .wednesday: return "dayname::wednesday".localized()
        case .thursday: return "dayname::thursday".localized()
        case .friday: return "dayname::friday".localized()
        case .saturday: return "dayname::saturday".localized()
        }
    }
    
    public var shortText: String {
        switch self {
        case .sunday: return "dayname::sunday:short".localized()
        case .monday: return "dayname::monday:short".localized()
        case .tuesday: return "dayname::tuesday:short".localized()
        case .wednesday: return "dayname::wednesday:short".localized()
        case .thursday: return "dayname::thursday:short".localized()
        case .friday: return "dayname::friday:short".localized()
        case .saturday: return "dayname::saturday:short".localized()
        }
    }
    
    public var veryShortText: String {
        switch self {
        case .sunday: return "dayname::sunday:very_short".localized()
        case .monday: return "dayname::monday:very_short".localized()
        case .tuesday: return "dayname::tuesday:very_short".localized()
        case .wednesday: return "dayname::wednesday:very_short".localized()
        case .thursday: return "dayname::thursday:very_short".localized()
        case .friday: return "dayname::friday:very_short".localized()
        case .saturday: return "dayname::saturday:very_short".localized()
        }
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
