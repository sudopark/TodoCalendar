//
//  SelectedTime.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


// MARK: - selectedTime

public struct SelectTimeText: Equatable {
    public var year: String?
    public let day: String
    public var time: String?
    public let date: Date

    public init(_ timeStamp: TimeInterval, _ timeZone: TimeZone, withoutTime: Bool = false) {
        let date = Date(timeIntervalSince1970: timeStamp)
        let isSameYear = Date().components(timeZone).0 == date.components(timeZone).0
        self.year = isSameYear ? nil : date.yearText(at: timeZone)
        self.day = date.dateText(at: timeZone)
        self.time = withoutTime ? nil : date.timeText(at: timeZone)
        self.date = date
    }

    public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.year == rhs.year && lhs.day == rhs.day && lhs.time == rhs.time
    }
}

public enum SelectedTime: Equatable {
    case at(SelectTimeText)
    case period(SelectTimeText, SelectTimeText)
    case singleAllDay(SelectTimeText)
    case alldayPeriod(SelectTimeText, SelectTimeText)

    public var isAllDay: Bool {
        switch self {
        case .singleAllDay, .alldayPeriod: return true
        default: return false
        }
    }

    public init(_ time: EventTime, _ timeZone: TimeZone) {
        switch time {
        case .at(let timeStamp):
            self = .at(
                .init(timeStamp, timeZone)
            )

        case .period(let range):
            self = .period(
                .init(range.lowerBound, timeZone), .init(range.upperBound, timeZone)
            )

        case .allDay:
            let range = time.rangeWithShifttingifNeed(on: timeZone)
            let isSameDay = Date(timeIntervalSince1970: range.lowerBound)
                .isSameDay(Date(timeIntervalSince1970: range.upperBound), at: timeZone)
            self = isSameDay
            ? .singleAllDay(.init(range.lowerBound, timeZone, withoutTime: true))
            : .alldayPeriod(.init(range.lowerBound, timeZone, withoutTime: true), .init(range.upperBound, timeZone, withoutTime: true))
        }
    }

    public var startDate: Date {
        switch self {
        case .at(let time): return time.date
        case .singleAllDay(let time): return time.date
        case .period(let start, _): return start.date
        case .alldayPeriod(let start, _): return start.date
        }
    }
}


extension Date {

    public func yearText(at timeZone: TimeZone) -> String {
        let dateForm = DateFormatter()
        dateForm.timeZone = timeZone
        dateForm.dateFormat = R.String.DateForm.yyyy
        return dateForm.string(from: self)
    }

    public func dateText(at timeZone: TimeZone) -> String {
        let dateForm = DateFormatter()
        dateForm.timeZone = timeZone
        dateForm.dateFormat = R.String.DateForm.mmmDdE
        return dateForm.string(from: self)
    }

    public func timeText(at timeZone: TimeZone) -> String {
        let timeForm = DateFormatter()
        timeForm.timeZone = timeZone
        timeForm.dateFormat = R.String.DateForm.hhMm
        return timeForm.string(from: self)
    }

    public func isSameDay(_ other: Date, at timeZone: TimeZone) -> Bool {
        let lhsCompos = self.components(timeZone)
        let rhsCompos = other.components(timeZone)
        return lhsCompos.0 == rhsCompos.0
            && lhsCompos.1 == rhsCompos.1
            && lhsCompos.2 == rhsCompos.2
    }

    public func components(_ timeZone: TimeZone) -> (Int?, Int?, Int?) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let compos = calendar.dateComponents([.year, .month, .day], from: self)
        return (compos.year, compos.month, compos.day)
    }
}
