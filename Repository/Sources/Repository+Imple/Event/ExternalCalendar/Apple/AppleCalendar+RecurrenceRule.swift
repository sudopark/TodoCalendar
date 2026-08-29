//
//  AppleCalendar+RecurrenceRule.swift
//  Repository
//
//  Created by sudo.park on 4/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import EventKit
import Domain


// MARK: - EKRecurrenceRule → RRULE string

extension EKRecurrenceRule {

    func toRRuleString() -> String {
        var parts: [String] = []
        parts.append("FREQ=\(frequency.rruleValue)")
        parts.append("INTERVAL=\(interval)")

        if let days = daysOfTheWeek, !days.isEmpty {
            let dayStrings = days.map { day -> String in
                let weekDayStr = day.dayOfTheWeek.rruleValue
                return day.weekNumber != 0
                    ? "\(day.weekNumber)\(weekDayStr)"
                    : weekDayStr
            }
            parts.append("BYDAY=\(dayStrings.joined(separator: ","))")
        }

        if let monthDays = daysOfTheMonth, !monthDays.isEmpty {
            parts.append("BYMONTHDAY=\(monthDays.map { $0.stringValue }.joined(separator: ","))")
        }

        if let months = monthsOfTheYear, !months.isEmpty {
            parts.append("BYMONTH=\(months.map { $0.stringValue }.joined(separator: ","))")
        }

        if let weeks = weeksOfTheYear, !weeks.isEmpty {
            parts.append("BYWEEKNO=\(weeks.map { $0.stringValue }.joined(separator: ","))")
        }

        if let yearDays = daysOfTheYear, !yearDays.isEmpty {
            parts.append("BYYEARDAY=\(yearDays.map { $0.stringValue }.joined(separator: ","))")
        }

        if let positions = setPositions, !positions.isEmpty {
            parts.append("BYSETPOS=\(positions.map { $0.stringValue }.joined(separator: ","))")
        }

        if let end = recurrenceEnd {
            if let endDate = end.endDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                parts.append("UNTIL=\(formatter.string(from: endDate))")
            } else if end.occurrenceCount > 0 {
                parts.append("COUNT=\(end.occurrenceCount)")
            }
        }

        if firstDayOfTheWeek > 0 && firstDayOfTheWeek != 2 {
            parts.append("WKST=\(Self.weekStartValue(firstDayOfTheWeek))")
        }

        return "RRULE:\(parts.joined(separator: ";"))"
    }

    private static func weekStartValue(_ value: NSInteger) -> String {
        switch value {
        case 1: return "SU"
        case 2: return "MO"
        case 3: return "TU"
        case 4: return "WE"
        case 5: return "TH"
        case 6: return "FR"
        case 7: return "SA"
        default: return "MO"
        }
    }
}


// MARK: - RRULE string → EKRecurrenceRule

extension EKRecurrenceRule {

    convenience init?(rruleText: String) {
        // 미지원 키는 되쓸 때 소실되므로 변환 자체를 막는다
        guard let rule = RRuleParser.parse(rruleText),
              rule.unsupportedKeys.isEmpty,
              rule.interval > 0
        else { return nil }

        let daysOfTheWeek = rule.byDays.isEmpty
            ? nil
            : rule.byDays.map {
                EKRecurrenceDayOfWeek($0.weekDay.ekWeekday, weekNumber: $0.ordinal ?? 0)
            }
        let daysOfTheMonth = rule.byMonthDays.isEmpty
            ? nil : rule.byMonthDays.map { NSNumber(value: $0) }
        let monthsOfTheYear = rule.byMonths.isEmpty
            ? nil : rule.byMonths.map { NSNumber(value: $0) }
        let end = rule.until.map { EKRecurrenceEnd(end: $0) }
            ?? rule.count.map { EKRecurrenceEnd(occurrenceCount: $0) }

        self.init(
            recurrenceWith: rule.freq.ekFrequency, interval: rule.interval,
            daysOfTheWeek: daysOfTheWeek, daysOfTheMonth: daysOfTheMonth,
            monthsOfTheYear: monthsOfTheYear, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: end
        )
    }
}


// MARK: - EKRecurrenceFrequency → RRULE FREQ value

private extension EKRecurrenceFrequency {

    var rruleValue: String {
        switch self {
        case .daily:   return "DAILY"
        case .weekly:  return "WEEKLY"
        case .monthly: return "MONTHLY"
        case .yearly:  return "YEARLY"
        @unknown default: return "DAILY"
        }
    }
}


// MARK: - RRULE FREQ value → EKRecurrenceFrequency

private extension RRule.Frequency {

    var ekFrequency: EKRecurrenceFrequency {
        switch self {
        case .DAILY:   return .daily
        case .WEEKLY:  return .weekly
        case .MONTHLY: return .monthly
        case .YEARLY:  return .yearly
        }
    }
}


// MARK: - EKWeekday → RRULE day abbreviation

private extension EKWeekday {

    var rruleValue: String {
        switch self {
        case .sunday:    return "SU"
        case .monday:    return "MO"
        case .tuesday:   return "TU"
        case .wednesday: return "WE"
        case .thursday:  return "TH"
        case .friday:    return "FR"
        case .saturday:  return "SA"
        @unknown default: return "MO"
        }
    }
}


// MARK: - RRULE day abbreviation → EKWeekday

private extension RRule.ByDay.WeekDay {

    var ekWeekday: EKWeekday {
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
