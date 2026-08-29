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

    public init?(customKey: String) {
        if customKey.contains("..<") {
            let parts = customKey.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
            let rangeString = String(parts[0])

            let components = rangeString.components(separatedBy: "..<")

            guard components.count == 2,
                  let lowerBound = Int(components[0]).map({ TimeInterval($0) }),
                  let upperBound = Int(components[1]).map({ TimeInterval($0) }) else {
                return nil
            }

            guard lowerBound <= upperBound else {
                return nil
            }

            if parts.count > 1 {
                guard let offset = Int(parts[1]).map({ TimeInterval($0) }) else {
                    return nil
                }
                self = .allDay(lowerBound..<upperBound, secondsFromGMT: offset)
            } else {
                self = .period(lowerBound..<upperBound)
            }
        } else {
            guard let time = Int(customKey).map({ TimeInterval($0) }) else {
                return nil
            }
            self = .at(time)
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

    /// `customKey`가 지목하는 회차의 시작 시각.
    ///
    /// 반복 열거는 시간순 전진이라, 어떤 회차를 키로 찾을 때 "이미 이 시각을 지났으면 없는 회차"로
    /// 판정할 수 있다. `customKey`의 세 형태 모두 시작 시각으로 시작하므로 앞쪽 정수만 읽는다 —
    /// customKey 포맷을 바꾸면 이 파서도 함께 갱신해야 한다.
    public static func lowerBound(fromCustomKey key: String) -> TimeInterval? {
        let head = key.prefix { $0.isNumber || $0 == "-" }
        return Int(head).map { TimeInterval($0) }
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
