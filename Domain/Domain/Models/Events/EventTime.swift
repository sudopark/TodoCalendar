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
    
    var timeZoneAbbreviation: String {
        switch self {
        case .at(let time): return time.timeZoneAbbreviation
        case .period(let range): return range.lowerBound.timeZoneAbbreviation
        }
    }
    
    var lowerBound: TimeInterval {
        switch self {
        case .at(let time): return time.utcTimeInterval
        case .period(let range): return range.lowerBound.utcTimeInterval
        }
    }
    
    var upperBound: TimeInterval {
        switch self {
        case .at(let time): return time.utcTimeInterval
        case .period(let range): return range.upperBound.utcTimeInterval
        }
    }
    
    func isClamped(with period: Range<TimeStamp>) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.clamped(to: period).isEmpty == false
        }
    }
    
    func shift(_ interval: TimeInterval) -> EventTime {
        switch self {
        case .at(let time):
            return .at(time.add(interval))
        case .period(let range):
            return .period(range.lowerBound.add(interval)..<range.upperBound.add(interval))
        }
    }
    
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.lowerBound < rhs.lowerBound
    }
}
