//
//  SelectedTime.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/1/23.
//

import Foundation
import Prelude
import Optics
import Domain


// MARK: - selectedTime

struct SelectTimeText: Equatable {
    var year: String?
    let day: String
    var time: String?
    let date: Date
    
    init(_ timeStamp: TimeInterval, _ timeZone: TimeZone, withoutTime: Bool = false) {
        let date = Date(timeIntervalSince1970: timeStamp)
        let isSameYear = Date().components(timeZone).0 == date.components(timeZone).0
        self.year = isSameYear ? nil : date.yearText(at: timeZone)
        self.day = date.dateText(at: timeZone)
        self.time = withoutTime ? nil : date.timeText(at: timeZone)
        self.date = date
    }
    
    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.year == rhs.year && lhs.day == rhs.day && lhs.time == rhs.time
    }
}

enum SelectedTime: Equatable {
    case at(SelectTimeText)
    case period(SelectTimeText, SelectTimeText)
    case singleAllDay(SelectTimeText)
    case alldayPeriod(SelectTimeText, SelectTimeText)
    
    var isAllDay: Bool {
        switch self {
        case .singleAllDay, .alldayPeriod: return true
        default: return false
        }
    }
    
    init(_ time: EventTime, _ timeZone: TimeZone) {
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
    
    var isValid: Bool {
        switch self {
        case .period(let start, let end): return start.date < end.date
        case .alldayPeriod(let start, let end): return start.date < end.date
        default: return true
        }
    }
    
    func eventTime(_ timeZone: TimeZone) -> EventTime? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let secondsFromGMT = timeZone.secondsFromGMT() |> TimeInterval.init
        switch self {
        case .at(let time):
            return .at(time.date.timeIntervalSince1970)
            
        case .period(let start, let end):
            guard start.date < end.date else { return nil }
            return .period(start.date.timeIntervalSince1970..<end.date.timeIntervalSince1970)
            
        case .singleAllDay(let time):
            guard let end = calendar.endOfDay(for: time.date) else { return nil }
            let start = calendar.startOfDay(for: time.date)
            return .allDay(
                start.timeIntervalSince1970..<end.timeIntervalSince1970,
                secondsFromGMT: secondsFromGMT
            )
        case .alldayPeriod(let start, let end):
            guard start.date < end.date, let endofEndDate = calendar.endOfDay(for: end.date)
            else { return nil }
            let startOfStarDate = calendar.startOfDay(for: start.date)
            return .allDay(
                startOfStarDate.timeIntervalSince1970..<endofEndDate.timeIntervalSince1970,
                secondsFromGMT: secondsFromGMT
            )
        }
    }
    
    func toggleIsAllDay(_ timeZone: TimeZone) -> SelectedTime? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        switch self {
        case .at(let time):
            return .singleAllDay(.init(time.date.timeIntervalSince1970, timeZone, withoutTime: true))
        case .period(let start, let end) where start.date.isSameDay(end.date, at: timeZone):
            return .singleAllDay(.init(start.date.timeIntervalSince1970, timeZone, withoutTime: true))
        case .period(let start, let end):
            return .alldayPeriod(start |> \.time .~ nil, end |> \.time .~ nil)
        case .singleAllDay(let time):
            guard let end = calendar.endOfDay(for: time.date) else { return nil }
            let start = calendar.startOfDay(for: time.date)
            return .period(
                .init(start.timeIntervalSince1970, timeZone),
                .init(end.timeIntervalSince1970, timeZone)
            )
        case .alldayPeriod(let start, let end):
            return .period(
                .init(start.date.timeIntervalSince1970, timeZone),
                .init(end.date.timeIntervalSince1970, timeZone)
            )
        }
    }
}

extension Optional where Wrapped == SelectedTime {
    
    func periodStartChanged(_ date: Date, _ timeZone: TimeZone) -> SelectedTime {
    
        let timeText = SelectTimeText(date.timeIntervalSince1970, timeZone)
        
        return switch self {
            case .none, .at: .at(timeText)
            case .period(_, let end): .period(timeText, end)
            case .singleAllDay(let start) where start.date.isSameDay(date, at: timeZone):
                .singleAllDay(timeText |> \.time .~ nil)
            case .singleAllDay:
                .singleAllDay(timeText)
            case .alldayPeriod(_, let end): .alldayPeriod(timeText |> \.time .~ nil, end)
        }
    }
    
    func periodEndTimeChanged(_ date: Date, _ timeZone: TimeZone) -> SelectedTime? {
        let timeText = SelectTimeText(date.timeIntervalSince1970, timeZone)
        return switch self {
            case .none: nil
            case .at(let start): .period(start, timeText)
            case .period(let start, _): .period(start, timeText)
            case .singleAllDay(let start) where start.date.isSameDay(date, at: timeZone): nil
            case .singleAllDay(let start): .alldayPeriod(start, timeText |> \.time .~ nil)
            case .alldayPeriod(let start, _): .alldayPeriod(start, timeText |> \.time .~ nil)
        }
    }
    
    func removePeriodEndTime(_ timeZone: TimeZone) -> SelectedTime? {
        return switch self {
        case .period(let start, _): .at(start)
        case .alldayPeriod(let start, _): .singleAllDay(start)
        default: nil
        }
    }
}


extension Date {
    
    func yearText(at timeZone: TimeZone) -> String {
        let dateForm = DateFormatter()
        dateForm.timeZone = timeZone
        dateForm.dateFormat = "yyyy".localized()
        return dateForm.string(from: self)
    }
    
    func dateText(at timeZone: TimeZone) -> String {
        let dateForm = DateFormatter()
        dateForm.timeZone = timeZone
        dateForm.dateFormat = "MMM dd (E)".localized()
        return dateForm.string(from: self)
    }
    
    func timeText(at timeZone: TimeZone) -> String {
        let timeForm = DateFormatter()
        timeForm.timeZone = timeZone
        timeForm.dateFormat = "HH:mm".localized()
        return timeForm.string(from: self)
    }
    
    func isSameDay(_ other: Date, at timeZone: TimeZone) -> Bool {
        let lhsCompos = self.components(timeZone)
        let rhsCompos = other.components(timeZone)
        return lhsCompos.0 == rhsCompos.0
            && lhsCompos.1 == rhsCompos.1
            && lhsCompos.2 == rhsCompos.2
    }
    
    func components(_ timeZone: TimeZone) -> (Int?, Int?, Int?) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let compos = calendar.dateComponents([.year, .month, .day], from: self)
        return (compos.year, compos.month, compos.day)
    }
}
