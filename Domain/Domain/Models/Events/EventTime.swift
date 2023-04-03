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
        case .allDays(let range): return range.lowerBound.timeIntervalWithUTCOffset
        }
    }
    
    func isClamped(with period: Range<TimeStamp>) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.clamped(to: period).isEmpty == false
        case .allDays(let range):
            return (range.lowerBound.timeIntervalWithUTCOffset..<range.upperBound.timeIntervalWithUTCOffset)
                .clamped(to: period.lowerBound.timeIntervalWithUTCOffset..<period.upperBound.timeIntervalWithUTCOffset)
                .isEmpty == false
        }
    }
    
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.lowerBound < rhs.lowerBound
    }
}
