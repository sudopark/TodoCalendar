//
//  AppleCalendar+RecurrenceRule.swift
//  Repository
//
//  Created by sudo.park on 4/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import EventKit


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

        // WKST=MO is the RFC 5545 default — omit unless it differs
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
