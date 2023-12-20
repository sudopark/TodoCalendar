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
        case .sunday: return "Sunday".localized()
        case .monday: return "Monday".localized()
        case .tuesday: return "Tueday".localized()
        case .wednesday: return "Wednesday".localized()
        case .thursday: return "Thursday".localized()
        case .friday: return "Friday".localized()
        case .saturday: return "Saturday".localized()
        }
    }
    
    public var shortText: String {
        switch self {
        case .sunday: return "SUN".localized()
        case .monday: return "MON".localized()
        case .tuesday: return "TUE".localized()
        case .wednesday: return "WED".localized()
        case .thursday: return "THU".localized()
        case .friday: return "FRI".localized()
        case .saturday: return "SAT".localized()
        }
    }
    
    public var veryShortText: String {
        switch self {
        case .sunday: return "S".localized()
        case .monday: return "M".localized()
        case .tuesday: return "T".localized()
        case .wednesday: return "W".localized()
        case .thursday: return "T".localized()
        case .friday: return "F".localized()
        case .saturday: return "S".localized()
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
