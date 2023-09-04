//
//  EventTime.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Prelude
import Optics


// MARK: - Event time

public enum EventTime: Comparable {
    
    case at(TimeInterval)
    case period(Range<TimeInterval>)
    case allDay(Range<TimeInterval>, secondsFromGMT: TimeInterval)

    public var lowerBoundWithFixed: TimeInterval {
        switch self {
        case .at(let time): return time
        case .period(let range): return range.lowerBound
        case .allDay(let range, _):
            return range.lowerBound
        }
    }
    
    public var upperBoundWithFixed: TimeInterval {
        switch self {
        case .at(let time): return time
        case .period(let range): return range.upperBound
        case .allDay(let range, _):
            return range.upperBound
        }
    }
    
    public func isOverlap(with period: Range<TimeInterval>) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.overlaps(period)
        case .allDay(let range, let secondsFromGMT):
            return range.intervalRanges(secondsFromGMT: secondsFromGMT).overlaps(period)
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
            
        case .allDay(let range, let secondsFromGMT):
            let clamped = range.intervalRanges(secondsFromGMT: secondsFromGMT).clamped(to: period)
            return clamped.isEmpty ? nil : clamped
        }
    }
    
    func shift(_ interval: TimeInterval) -> EventTime {
        switch self {
        case .at(let time):
            return .at(time + interval)
        case .period(let range):
            return .period(range.shift(interval))
        case .allDay(let range, let secondsFromGMT):
            return .allDay(range.shift(interval), secondsFromGMT: secondsFromGMT)
        }
    }
    
    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.lowerBoundWithFixed < rhs.lowerBoundWithFixed
    }
    
    public var customKey: String {
        switch self {
        case .at(let time): return "\(time)"
        case .period(let range):
            return "\(range.lowerBound)..<\(range.upperBound)"
        case .allDay(let range, let secondsFromGMT):
            return "\(range.lowerBound)..<\(range.upperBound)+\(secondsFromGMT)"
        }
    }
    
    public func rangeWithShifttingifNeed(on timeZone: TimeZone) -> Range<TimeInterval> {
        switch self {
        case .at(let time): return time..<time
        case .period(let range): return range
        case .allDay(let range, let secondsFromGMT):
            return range.shiftting(secondsFromGMT, to: timeZone)
        }
    }
}

public extension Range where Bound == TimeInterval {
    
    func shiftting(_ secondsFromGMT: TimeInterval, to timeZone: TimeZone) -> Range {
        
        let utcRange = self.lowerBound+secondsFromGMT..<self.upperBound+secondsFromGMT
        let givenTimeZoneSecondsFromGMT = timeZone.secondsFromGMT() |> TimeInterval.init
        return utcRange.lowerBound-givenTimeZoneSecondsFromGMT..<utcRange.upperBound-givenTimeZoneSecondsFromGMT
    }
}
