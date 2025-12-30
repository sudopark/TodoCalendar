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

public enum EventTime: Comparable, Sendable, Hashable {
    
    case at(TimeInterval)
    case period(Range<TimeInterval>)
    case allDay(Range<TimeInterval>, secondsFromGMT: TimeInterval)
    
    public init?(deepLink queryParams: [String: String]) {
        
        let at = queryParams["at"].flatMap { TimeInterval($0) }
        let period_start = queryParams["start"].flatMap { TimeInterval($0) }
        let period_end = queryParams["end"].flatMap { TimeInterval($0) }
        let secondsFromGMT = queryParams["offset"].flatMap { TimeInterval($0) }
        let isAllDay = queryParams["isAllDay"].map {  $0 == "true" ? true : false }
        
        if let at {
            self = .at(at)
        } else if let start = period_start, let end = period_end, isAllDay == true, let offset = secondsFromGMT {
            self = .allDay(start..<end, secondsFromGMT: offset)
        } else if let start = period_start, let end = period_end {
            self = .period(start..<end)
        } else {
            return nil
        }
    }
    
    public var queryParams: [String: String] {
        switch self {
        case .at(let interval):
            return ["at": "\(interval)"]
            
        case .period(let range):
            return [
                "start": "\(range.lowerBound)",
                "end": "\(range.upperBound)"
            ]
            
        case .allDay(let range, let secondsFromGMT):
            return [
                "start": "\(range.lowerBound)",
                "end": "\(range.upperBound)",
                "offset": "\(secondsFromGMT)",
                "isAllDay": "true"
            ]
        }
    }
    
    public var isAllDay: Bool {
        guard case .allDay = self else { return false }
        return true
    }

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
    
    ///  allDayEvent의 경우 지정한 날짜를 어떤 타임존에서 조회하더라도 검색가능해야하기때문에 -> 날짜 검사 범위 확대
    public func isRoughlyOverlap(with period: Range<TimeInterval>) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.overlaps(period)
        case .allDay(let range, let secondsFromGMT):
            return range.intervalRanges(secondsFromGMT: secondsFromGMT).overlaps(period)
        }
    }
    
    public func isOverlap(with period: Range<TimeInterval>, in timeZone: TimeZone) -> Bool {
        switch self {
        case .at(let time):
            return period ~= time
        case .period(let range):
            return range.overlaps(period)
        case .allDay(let range, let secondsFromGMT):
            let shiftedRange = range.shiftting(secondsFromGMT, to: timeZone)
            return shiftedRange.overlaps(period)
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
        case .at(let time): return "\(Int(time))"
        case .period(let range):
            return "\(Int(range.lowerBound))..<\(Int(range.upperBound))"
        case .allDay(let range, let secondsFromGMT):
            return "\(Int(range.lowerBound))..<\(Int(range.upperBound))+\(Int(secondsFromGMT))"
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
