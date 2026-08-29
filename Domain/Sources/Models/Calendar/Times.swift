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
    
    private var localizeKeyStem: String {
        switch self {
        case .sunday: return "dayname::sunday"
        case .monday: return "dayname::monday"
        case .tuesday: return "dayname::tuesday"
        case .wednesday: return "dayname::wednesday"
        case .thursday: return "dayname::thursday"
        case .friday: return "dayname::friday"
        case .saturday: return "dayname::saturday"
        }
    }

    public var text: String {
        return self.localizeKeyStem.localized()
    }

    public var localizedGrammaticalGender: String {
        return "\(self.localizeKeyStem):gender".localized()
    }

    public var shortText: String {
        return "\(self.localizeKeyStem):short".localized()
    }

    public var veryShortText: String {
        return "\(self.localizeKeyStem):very_short".localized()
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
