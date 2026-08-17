//
//  RRule+EventRepeating.swift
//  Domain
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


// MARK: - RRULE → 앱 반복 옵션

extension RRule {

    public func asEventRepeating(startTime: TimeInterval, timeZone: TimeZone) -> EventRepeating? {
        guard self.unsupportedKeys.isEmpty, self.interval > 0,
              let option = self.asEventRepeatingOption(startTime: startTime, timeZone: timeZone)
        else { return nil }

        return EventRepeating(repeatingStartTime: startTime, repeatOption: option)
            |> \.repeatingEndOption .~ self.asRepeatEndOption()
    }

    private func asEventRepeatingOption(
        startTime: TimeInterval, timeZone: TimeZone
    ) -> (any EventRepeatingOption)? {
        switch self.freq {
        case .DAILY: return self.asEveryDayOption()
        case .WEEKLY: return self.asEveryWeekOption(startTime: startTime, timeZone: timeZone)
        case .MONTHLY: return self.asEveryMonthOption(startTime: startTime, timeZone: timeZone)
        case .YEARLY: return self.asEveryYearOption(startTime: startTime, timeZone: timeZone)
        }
    }

    private func asEveryDayOption() -> (any EventRepeatingOption)? {
        guard self.byDays.isEmpty, self.byMonthDays.isEmpty, self.byMonths.isEmpty
        else { return nil }
        return EventRepeatingOptions.EveryDay() |> \.interval .~ self.interval
    }

    private func asEveryWeekOption(
        startTime: TimeInterval, timeZone: TimeZone
    ) -> (any EventRepeatingOption)? {
        guard self.byMonthDays.isEmpty, self.byMonths.isEmpty,
              self.byDays.allSatisfy({ $0.ordinal == nil })
        else { return nil }

        let days: [DayOfWeeks] = self.byDays.isEmpty
            ? [startTime.weekdayComponent(in: timeZone)]
            : self.byDays.map { $0.weekDay.asDayOfWeeks }
        return EventRepeatingOptions.EveryWeek(timeZone)
            |> \.interval .~ self.interval
            |> \.dayOfWeeks .~ days
    }

    private func asEveryMonthOption(
        startTime: TimeInterval, timeZone: TimeZone
    ) -> (any EventRepeatingOption)? {
        guard let selection = self.asMonthlySelection(startTime: startTime, timeZone: timeZone)
        else { return nil }
        return EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.interval .~ self.interval
            |> \.selection .~ selection
    }

    private func asMonthlySelection(
        startTime: TimeInterval, timeZone: TimeZone
    ) -> EventRepeatingOptions.EveryMonth.DateSelector? {
        switch (self.byDays.isEmpty, self.byMonthDays.isEmpty, self.byMonths.isEmpty) {
        case (true, false, true):
            guard let monthDays = self.byMonthDays.asMonthDays() else { return nil }
            return .days(monthDays)

        case (false, true, true):
            guard let selector = self.byDays.asWeekSelector() else { return nil }
            return .week(selector.ordinals, selector.weekDays)

        case (true, true, true):
            return .days([startTime.dayComponent(in: timeZone)])

        default:
            return nil
        }
    }

    private func asEveryYearOption(
        startTime: TimeInterval, timeZone: TimeZone
    ) -> (any EventRepeatingOption)? {
        if self.byMonths.count == 1, self.byMonthDays.count == 1, self.byDays.isEmpty {
            guard let months = self.byMonths.asMonths(), let monthDays = self.byMonthDays.asMonthDays()
            else { return nil }
            return EventRepeatingOptions.EveryYearSomeDay(timeZone, months[0].rawValue, monthDays[0])
                |> \.interval .~ self.interval
        }
        if self.byMonths.isEmpty, self.byMonthDays.isEmpty, self.byDays.isEmpty {
            let (month, day) = startTime.monthAndDayComponents(in: timeZone)
            return EventRepeatingOptions.EveryYearSomeDay(timeZone, month, day)
                |> \.interval .~ self.interval
        }
        guard self.byMonths.isEmpty == false, self.byMonthDays.isEmpty, self.byDays.isEmpty == false,
              let months = self.byMonths.asMonths(),
              let selector = self.byDays.asWeekSelector()
        else { return nil }

        return EventRepeatingOptions.EveryYear(timeZone: timeZone)
            |> \.interval .~ self.interval
            |> \.months .~ months
            |> \.weekOrdinals .~ selector.ordinals
            |> \.dayOfWeek .~ selector.weekDays
    }

    private func asRepeatEndOption() -> EventRepeating.RepeatEndOption? {
        if let until = self.until {
            return .until(until.timeIntervalSince1970)
        }
        if let count = self.count {
            return .count(count)
        }
        return nil
    }
}


// MARK: - 앱 반복 옵션 → RRULE

extension EventRepeating {

    public func asRRuleText(_ timeZone: TimeZone) -> String? {
        guard let rrule = self.repeatOptionAsRRule() else { return nil }
        return (
            rrule
                |> \.until .~ self.repeatingEndOption?.endTime.map(Date.init(timeIntervalSince1970:))
                |> \.count .~ self.repeatingEndOption?.endCount
        )
        .asRRuleText()
    }

    private func repeatOptionAsRRule() -> RRule? {
        if let option = self.repeatOption as? EventRepeatingOptions.EveryDay {
            return option.asRRule()
        }
        if let option = self.repeatOption as? EventRepeatingOptions.EveryWeek {
            return option.asRRule()
        }
        if let option = self.repeatOption as? EventRepeatingOptions.EveryMonth {
            return option.asRRule()
        }
        if let option = self.repeatOption as? EventRepeatingOptions.EveryYear {
            return option.asRRule()
        }
        if let option = self.repeatOption as? EventRepeatingOptions.EveryYearSomeDay {
            return option.asRRule()
        }
        return nil
    }
}

extension EventRepeatingOptions.EveryDay {

    fileprivate func asRRule() -> RRule? {
        guard self.interval > 0 else { return nil }
        return RRule(freq: .DAILY, interval: self.interval)
    }
}

extension EventRepeatingOptions.EveryWeek {

    fileprivate func asRRule() -> RRule? {
        guard self.interval > 0, self.dayOfWeeks.isEmpty == false else { return nil }
        return RRule(
            freq: .WEEKLY, interval: self.interval,
            byDays: self.dayOfWeeks.map { RRule.ByDay(weekDay: $0.asRRuleWeekDay) }
        )
    }
}

extension EventRepeatingOptions.EveryMonth {

    fileprivate func asRRule() -> RRule? {
        guard self.interval > 0 else { return nil }
        switch self.selection {
        case .days(let days):
            guard days.isEmpty == false else { return nil }
            return RRule(freq: .MONTHLY, interval: self.interval, byMonthDays: days)

        case .week(let ordinals, let weekDays):
            guard ordinals.isEmpty == false, weekDays.isEmpty == false else { return nil }
            return RRule(
                freq: .MONTHLY, interval: self.interval,
                byDays: ordinals.asRRuleByDays(weekDays)
            )
        }
    }
}

extension EventRepeatingOptions.EveryYear {

    fileprivate func asRRule() -> RRule? {
        guard self.interval > 0,
              self.months.isEmpty == false,
              self.weekOrdinals.isEmpty == false,
              self.dayOfWeek.isEmpty == false
        else { return nil }
        return RRule(
            freq: .YEARLY, interval: self.interval,
            byDays: self.weekOrdinals.asRRuleByDays(self.dayOfWeek),
            byMonths: self.months.map { $0.rawValue }
        )
    }
}

extension EventRepeatingOptions.EveryYearSomeDay {

    fileprivate func asRRule() -> RRule? {
        guard self.interval > 0 else { return nil }
        return RRule(
            freq: .YEARLY, interval: self.interval,
            byMonthDays: [self.day], byMonths: [self.month]
        )
    }
}


// MARK: - RRule.ByDay ↔ WeekOrdinal · DayOfWeeks 변환

extension Array where Element: Equatable {

    fileprivate func uniqueInOrder() -> [Element] {
        return self.reduce(into: [Element]()) { acc, element in
            guard acc.contains(element) == false else { return }
            acc.append(element)
        }
    }
}

extension Array where Element == RRule.ByDay {

    fileprivate func asWeekSelector() -> (ordinals: [WeekOrdinal], weekDays: [DayOfWeeks])? {
        let parsedOrdinals = self.compactMap { $0.ordinal }
        guard parsedOrdinals.count == self.count else { return nil }

        let ordinalValues = parsedOrdinals.uniqueInOrder()
        let weekDayValues = self.map { $0.weekDay }.uniqueInOrder()

        guard self.count == ordinalValues.count * weekDayValues.count else { return nil }

        let expectedKeys = Set(
            ordinalValues.flatMap { ordinal in weekDayValues.map { "\(ordinal)-\($0.rawValue)" } }
        )
        let actualKeys = Set(Swift.zip(parsedOrdinals, self.map { $0.weekDay }).map { "\($0)-\($1.rawValue)" })
        guard expectedKeys == actualKeys else { return nil }

        let ordinals = ordinalValues.compactMap { WeekOrdinal(rruleOrdinal: $0) }
        guard ordinals.count == ordinalValues.count else { return nil }

        return (ordinals, weekDayValues.map { $0.asDayOfWeeks })
    }
}

extension Array where Element == WeekOrdinal {

    fileprivate func asRRuleByDays(_ weekDays: [DayOfWeeks]) -> [RRule.ByDay] {
        return self.flatMap { ordinal in
            weekDays.map { RRule.ByDay(ordinal: ordinal.asRRuleOrdinal, weekDay: $0.asRRuleWeekDay) }
        }
    }
}

extension Array where Element == Int {

    fileprivate func asMonths() -> [Months]? {
        let months = self.compactMap { Months(rawValue: $0) }
        return months.count == self.count ? months : nil
    }

    fileprivate func asMonthDays() -> [Int]? {
        let monthDays = self.filter { (1...31).contains($0) }
        return monthDays.count == self.count ? monthDays : nil
    }
}

extension WeekOrdinal {

    fileprivate init?(rruleOrdinal ordinal: Int) {
        switch ordinal {
        case -1: self = .last
        case let n where n > 0: self = .seq(n)
        default: return nil
        }
    }

    fileprivate var asRRuleOrdinal: Int {
        switch self {
        case .last: return -1
        case .seq(let n): return n
        }
    }
}

extension RRule.ByDay.WeekDay {

    fileprivate var asDayOfWeeks: DayOfWeeks {
        switch self {
        case .SU: return .sunday
        case .MO: return .monday
        case .TU: return .tuesday
        case .WE: return .wednesday
        case .TH: return .thursday
        case .FR: return .friday
        case .SA: return .saturday
        }
    }
}

extension DayOfWeeks {

    fileprivate var asRRuleWeekDay: RRule.ByDay.WeekDay {
        switch self {
        case .sunday: return .SU
        case .monday: return .MO
        case .tuesday: return .TU
        case .wednesday: return .WE
        case .thursday: return .TH
        case .friday: return .FR
        case .saturday: return .SA
        }
    }
}


// MARK: - TimeInterval → 반복 시작 시각의 요일·일자

extension TimeInterval {

    fileprivate func weekdayComponent(in timeZone: TimeZone) -> DayOfWeeks {
        let value = self.dateComponents([.weekday], in: timeZone).weekday ?? DayOfWeeks.sunday.rawValue
        return DayOfWeeks(rawValue: value) ?? .sunday
    }

    fileprivate func dayComponent(in timeZone: TimeZone) -> Int {
        return self.dateComponents([.day], in: timeZone).day ?? 1
    }

    fileprivate func monthAndDayComponents(in timeZone: TimeZone) -> (month: Int, day: Int) {
        let components = self.dateComponents([.month, .day], in: timeZone)
        return (components.month ?? 1, components.day ?? 1)
    }

    private func dateComponents(_ units: Set<Calendar.Component>, in timeZone: TimeZone) -> DateComponents {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        return calendar.dateComponents(units, from: Date(timeIntervalSince1970: self))
    }
}
