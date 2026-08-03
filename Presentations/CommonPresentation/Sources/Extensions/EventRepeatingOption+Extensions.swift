//
//  EventRepeatingOption+Extensions.swift
//  CommonPresentation
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


private typealias Options = EventRepeatingOptions


// MARK: - EventRepeatingOption + summaryText

public extension EventRepeatingOption {

    /// 반복 주기를 사람이 읽는 한 줄 요약으로. 지원하지 않는 조합이면 nil.
    func summaryText(startTime: Date, timeZone: TimeZone) -> String? {

        guard let supportOption = SupportingOptions(self) else { return nil }
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone

        switch supportOption {
        case .everyDay:
            return R.String.EventDetail.Repeating.everyDayTitle

        case .everyWeek(let seq, let weekDay) where seq == 1:
            return weekDay.rawValue == calendar.component(.weekday, from: startTime)
                ? "eventDetail.repeating.everyWeek:title".localized()
                : "eventDetail.repeating.everyWeekSomeDay:title".localized(with: weekDay.text)

        case .everyWeekDays:
            return "eventDetail.repeating.everyWeekDays:title".localized()

        case .everyWeek(let seq, let weekDay):
            return weekDay.rawValue == calendar.component(.weekday, from: startTime)
                ? "eventDetail.repeating.everySomeWeek:title".localized(with: seq)
                : "eventDetail.repeating.everySomeWeekSomeDay:title".localized(with: seq, weekDay.text)

        case .everyMonth(let day):
            guard calendar.component(.day, from: startTime) != day
            else { return "eventDetail.repeating.everyMonth:title".localized() }
            let ordinal = day.ordinal ?? "\(day)"
            return "eventDetail.repeating.everyMonth_someDay:title".localized(with: ordinal)

        case .everyYear(let month, let day):
            guard calendar.component(.month, from: startTime) != month
                    || calendar.component(.day, from: startTime) != day
            else { return "eventDetail.repeating.everyYear:title".localized() }
            return "eventDetail.repeating.everyYearSomeDay:title"
                .localized(with: calendar.dateText(month, day))

        case .lunarCalendarEveryYear(let month, let day):
            guard calendar.component(.month, from: startTime) != month
                    || calendar.component(.day, from: startTime) != day
            else { return "eventDetail.repeating.lunarCalendar_everyYear:title".localized() }
            return "eventDetail.repeating.lunarCalendar_everyYearSomeDay:title"
                .localized(with: calendar.dateText(month, day))

        case .everyMonthLastAllWeekDays:
            return R.String.EventDetail.Repeating.everyLastWeekDaysOfEveryMonthTitle

        case .everyMonthSomeWeekDay(let seq, let weekDay):
            return "eventDetail.repeating.every\(seq)WeekOfEveryMonth::someday"
                .localized(with: weekDay.text)

        case .everyMonthLastWeekDay(let weekDay):
            return R.String.EventDetail.Repeating.everyLastWeekOfEveryMonthSomeday(weekDay.text)
        }
    }
}


// MARK: - SupportingOptions

private enum SupportingOptions: Equatable {

    case everyDay
    case everyWeek(_ interval: Int, _ weekDay: DayOfWeeks)
    case everyWeekDays
    case everyMonth(_ day: Int)
    case everyYear(_ month: Int, _ day: Int)
    case everyMonthLastAllWeekDays
    case everyMonthSomeWeekDay(_ seq: Int, weekDay: DayOfWeeks)
    case everyMonthLastWeekDay(_ weekDay: DayOfWeeks)
    case lunarCalendarEveryYear(_ month: Int, _ day: Int)

    init?(_ option: any EventRepeatingOption) {
        switch option {
        case let day as Options.EveryDay where day.interval == 1:
            self = .everyDay

        case let week as Options.EveryWeek where week.dayOfWeeks.count == 1:
            self = .everyWeek(week.interval, week.dayOfWeeks[0])

        case let week as Options.EveryWeek where week.interval == 1 && week.isEveryWeekDays:
            self = .everyWeekDays

        case let month as Options.EveryMonth:
            guard let support = SupportingOptions(month: month) else { return nil }
            self = support

        case let year as Options.EveryYearSomeDay where year.interval == 1:
            self = .everyYear(year.month, year.day)

        case let year as Options.LunarCalendarEveryYear:
            self = .lunarCalendarEveryYear(year.month, year.day)

        default: return nil
        }
    }

    private init?(month: Options.EveryMonth) {
        guard month.interval == 1 else { return nil }

        switch month.selection {
        case .days(let days):
            guard let day = days.first else { return nil }
            self = .everyMonth(day)

        case .week(let ordinals, let weekdays):
            guard let ordinal = ordinals.first, let firstWeekDay = weekdays.first
            else { return nil }
            if case let .seq(seq) = ordinal, weekdays.count == 1 {
                self = .everyMonthSomeWeekDay(seq, weekDay: firstWeekDay)
            } else if weekdays.count == 7 {
                self = .everyMonthLastAllWeekDays
            } else if weekdays.count == 1 {
                self = .everyMonthLastWeekDay(firstWeekDay)
            } else {
                return nil
            }
        }
    }
}


// MARK: - Calendar

private extension Calendar {

    func dateText(_ month: Int, _ day: Int) -> String {
        guard let date = self.date(bySetting: .month, value: month, of: Date())
            .flatMap({ self.date(bySetting: .day, value: day, of: $0) })
        else { return "\(month).\(day)" }
        return date.text("date_form::MMM_d".localized())
    }
}
