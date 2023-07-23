//
//  EventTime.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


// MARK: - Event time

public enum EventTime: Comparable {
    
    case at(TimeInterval)
    case period(Range<TimeInterval>)

    public var lowerBound: TimeInterval {
        switch self {
        case .at(let time): return time
        case .period(let range): return range.lowerBound
        }
    }
    
    public var upperBound: TimeInterval {
        switch self {
        case .at(let time): return time
        case .period(let range): return range.upperBound
        }
    }
    
    public func isOverlap(with period: Range<TimeInterval>) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.overlaps(period)
        }
    }
    
    public func clamped(to period: Range<TimeInterval>) -> Range<TimeInterval>? {
        switch self {
        case .at(let time):
            return period ~= time
                ? time..<time
                : nil
        case .period(let range):
            let clamped = range.clamped(to: period)
            return clamped.isEmpty ? nil : clamped
        }
    }
    
    func shift(_ interval: TimeInterval) -> EventTime {
        switch self {
        case .at(let time):
            return .at(time + interval)
        case .period(let range):
            return .period(range.lowerBound+interval..<range.upperBound+interval)
        }
    }
    
    func shift(to timeStamp: TimeInterval) -> EventTime {
        switch self {
        case .at(let time):
            let interval = timeStamp - time
            return .at(time + interval)
        case .period(let ranege):
            let interval = timeStamp - ranege.lowerBound
            return .period(ranege.lowerBound+interval..<ranege.upperBound+interval)
        }
    }
    
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.lowerBound < rhs.lowerBound
    }
    
    public var customKey: String {
        switch self {
        case .at(let time): return "\(time)"
        case .period(let range):
            return "\(range.lowerBound)..<\(range.upperBound)"
        }
    }
}
