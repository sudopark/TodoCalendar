//
//  EventTime.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


// MARK: - Event time

public enum EventTime: Comparable {
    
    case at(TimeStamp)
    case period(Range<TimeStamp>)
    case allDays(Range<TimeStamp>)
    
    var lowerBound: TimeInterval {
        switch self {
        case .at(let time): return time.timeInterval
        case .period(let range): return range.lowerBound.timeInterval
        case .allDays(let range): return range.lowerBound.timeInterval
        }
    }
    
    var lowerBoundWithFixedTimeZoneOffset: TimeInterval {
        switch self {
        case .at(let time): return time.timeInterval
        case .period(let range): return range.lowerBound.timeInterval
        case .allDays(let range): return range.lowerBound.timeIntervalWithTimeZoneOffset
        }
    }
    
    var upperBound: TimeInterval {
        switch self {
        case .at(let time): return time.timeInterval
        case .period(let range): return range.upperBound.timeInterval
        case .allDays(let range): return range.upperBound.timeInterval
        }
    }
    
    var upperBoundWithFixedTimeZoneOffset: TimeInterval {
        switch self {
        case .at(let time): return time.timeInterval
        case .period(let range): return range.upperBound.timeInterval
        case .allDays(let range): return range.upperBound.timeIntervalWithTimeZoneOffset
        }
    }
    
    func isClamped(with period: Range<TimeStamp>) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.clamped(to: period).isEmpty == false
        case .allDays(let range):
            return (range.lowerBound.timeInterval..<range.upperBound.timeInterval)
                .clamped(to: period.lowerBound.timeInterval..<period.upperBound.timeInterval)
                .isEmpty == false
        }
    }
    
    func shift(_ interval: TimeInterval) -> EventTime {
        switch self {
        case .at(let time):
            return .at(time.add(interval))
        case .period(let range):
            return .period(range.lowerBound.add(interval)..<range.upperBound.add(interval))
        case .allDays(let range):
            return .allDays(range.lowerBound.add(interval)..<range.upperBound.add(interval))
        }
    }
    
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.lowerBound < rhs.lowerBound
    }
}
