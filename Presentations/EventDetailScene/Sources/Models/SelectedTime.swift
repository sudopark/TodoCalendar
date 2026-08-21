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
import Extensions
import CommonPresentation


// MARK: - selectedTime

extension SelectedTime {

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
                .singleAllDay(timeText |> \.time .~ nil)
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
