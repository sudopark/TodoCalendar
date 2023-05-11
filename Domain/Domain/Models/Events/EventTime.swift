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
    
    var lowerBoundTimeStamp: TimeStamp {
        switch self {
        case .at(let time): return time
        case .period(let range): return range.lowerBound
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
    
    func isOverlap(with period: Range<TimeStamp>) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.overlaps(period)
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
    
    func shift(to timeStamp: TimeStamp) -> EventTime {
        switch self {
        case .at(let time):
            let interval = timeStamp.utcTimeInterval - time.utcTimeInterval
            return .at(time.add(interval))
        case .period(let ranege):
            let interval = timeStamp.utcTimeInterval - ranege.lowerBound.utcTimeInterval
            return .period(ranege.lowerBound.add(interval)..<ranege.upperBound.add(interval))
        }
    }
    
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.lowerBound < rhs.lowerBound
    }
    
    var customKey: String {
        switch self {
        case .at(let time): return "\(time.utcTimeInterval)"
        case .period(let range):
            return "\(range.lowerBound.utcTimeInterval)..<\(range.upperBound.utcTimeInterval)"
        }
    }
}
