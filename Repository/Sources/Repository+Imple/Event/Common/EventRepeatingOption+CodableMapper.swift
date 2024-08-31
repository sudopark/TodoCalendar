//
//  EventRepeatingOption+CodableMapper.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
import Domain
import Extensions

struct EventRepeatingOptionCodableMapper: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case optionType
        case interval
        case timeZone
        case dayOfWeek
        case monthDaySelection
        case months
        case weekOrdinals
        case month
        case day
    }
    
    let option: any EventRepeatingOption
    init(option: any EventRepeatingOption) {
        self.option = option
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let optionType: String = try container.decode(String.self, forKey: .optionType)
        let timeZoneIdentifier = try? container.decode(String.self, forKey: .timeZone)
        switch optionType {
        case "every_day":
            var option = EventRepeatingOptions.EveryDay()
            option.interval = try container.decode(Int.self, forKey: .interval)
            self = .init(option: option)
            
        case "every_week":
            guard let timeZone = timeZoneIdentifier.flatMap ({ TimeZone(identifier: $0) })
            else {
                throw RuntimeError("invalid time zone value: \(timeZoneIdentifier ?? "")")
            }
            var option = EventRepeatingOptions.EveryWeek(timeZone)
            option.interval = try container.decode(Int.self, forKey: .interval)
            let dayOfWeeks = try container.decode([Int].self, forKey: .dayOfWeek)
            option.dayOfWeeks = dayOfWeeks.compactMap { DayOfWeeks(rawValue: $0) }
            self = .init(option: option)
            
        case "every_month":
            guard let timeZone = timeZoneIdentifier.flatMap ({ TimeZone(identifier: $0) })
            else {
                throw RuntimeError("invalid time zone value: \(timeZoneIdentifier ?? "")")
            }
            var option = EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            option.interval = try container.decode(Int.self, forKey: .interval)
            let selection = try container.decode(EveryMonthDateSelectorMapper.self, forKey: .monthDaySelection)
            option.selection = selection.selector
            self = .init(option: option)
            
        case "every_year":
            guard let timeZone = timeZoneIdentifier.flatMap ({ TimeZone(identifier: $0) })
            else {
                throw RuntimeError("invalid time zone value: \(timeZoneIdentifier ?? "")")
            }
            var option = EventRepeatingOptions.EveryYear(timeZone: timeZone)
            option.interval = try container.decode(Int.self, forKey: .interval)
            let months = try container.decode([Int].self, forKey: .months)
            let dayofWeeks = try container.decode([Int].self, forKey: .dayOfWeek)
            option.months = months.compactMap { Months(rawValue: $0) }
            option.dayOfWeek = dayofWeeks.compactMap { DayOfWeeks(rawValue: $0) }
            self = .init(option: option)
            
        case "every_year_some_day":
            guard let timeZone = timeZoneIdentifier.flatMap ({ TimeZone(identifier: $0) })
            else {
                throw RuntimeError("invalid time zone value: \(timeZoneIdentifier ?? "")")
            }
            var option = EventRepeatingOptions.EveryYearSomeDay(
                timeZone,
                try container.decode(Int.self, forKey: .month),
                try container.decode(Int.self, forKey: .day)
            )
            option.interval = try container.decode(Int.self, forKey: .interval)
            self = .init(option: option)
            
        default: throw RuntimeError("not support option type")
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.option {
        case let everyDay as EventRepeatingOptions.EveryDay:
            try container.encode("every_day", forKey: .optionType)
            try container.encode(everyDay.interval, forKey: .interval)
            
        case let everyWeek as EventRepeatingOptions.EveryWeek:
            try container.encode("every_week", forKey: .optionType)
            try container.encode(everyWeek.interval, forKey: .interval)
            try container.encode(everyWeek.dayOfWeeks.map { $0.rawValue }, forKey: .dayOfWeek)
            try container.encodeIfPresent(everyWeek.timeZone.identifier, forKey: .timeZone)
            
        case let everyMonth as EventRepeatingOptions.EveryMonth:
            try container.encode("every_month", forKey: .optionType)
            try container.encode(everyMonth.interval, forKey: .interval)
            try container.encode(EveryMonthDateSelectorMapper(selector: everyMonth.selection), forKey: .monthDaySelection)
            try container.encodeIfPresent(everyMonth.timeZone.identifier, forKey: .timeZone)
            
        case let everyYear as EventRepeatingOptions.EveryYear:
            try container.encode("every_year", forKey: .optionType)
            try container.encode(everyYear.interval, forKey: .interval)
            try container.encode(everyYear.months.map { $0.rawValue }, forKey: .months)
            try container.encode(everyYear.weekOrdinals.map { WeekOrdinalMapper(ordinal: $0) }, forKey: .weekOrdinals)
            try container.encode(everyYear.dayOfWeek.map { $0.rawValue }, forKey: .dayOfWeek)
            try container.encodeIfPresent(everyYear.timeZone.identifier, forKey: .timeZone)
            
        case let everyYear as EventRepeatingOptions.EveryYearSomeDay:
            try container.encode("every_year_some_day", forKey: .optionType)
            try container.encode(everyYear.interval, forKey: .interval)
            try container.encodeIfPresent(everyYear.timeZone.identifier, forKey: .timeZone)
            
        default: throw RuntimeError("not support option type")
        }
    }
}

private struct WeekOrdinalMapper: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case seq
        case isLast
    }
    
    let ordinal: WeekOrdinal
    init(ordinal: WeekOrdinal) {
        self.ordinal = ordinal
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isLast: Bool = try container.decode(Bool.self, forKey: .isLast)
        if isLast {
            self = .init(ordinal: .last)
        } else {
            self = .init(ordinal: .seq(try container.decode(Int.self, forKey: .seq)))
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.ordinal {
        case .last:
            try container.encode(true, forKey: .isLast)
        case .seq(let value):
            try container.encode(false, forKey: .isLast)
            try container.encode(value, forKey: .seq)
        }
    }
}

private struct EveryMonthDateSelectorMapper: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case days
        case weekOrdinals
        case weekDays
    }
    
    let selector: EventRepeatingOptions.EveryMonth.DateSelector
    init(selector: EventRepeatingOptions.EveryMonth.DateSelector) {
        self.selector = selector
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let days = try? container.decode([Int].self, forKey: .days) {
            self = .init(selector: .days(days))
        } else {
            let ordinalMapper = try container.decode([WeekOrdinalMapper].self, forKey: .weekOrdinals)
            let weekDays = try container.decode([Int].self, forKey: .weekDays)
            self = .init(selector:
                    .week(ordinalMapper.map { $0.ordinal },
                          weekDays.compactMap { DayOfWeeks(rawValue: $0) }
                         )
            )
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.selector {
        case .days(let days):
            try container.encode(days, forKey: .days)
            
        case .week(let ordinals, let weekDays):
            let ordinalMapper = ordinals.map { WeekOrdinalMapper(ordinal: $0) }
            try container.encode(ordinalMapper, forKey: .weekOrdinals)
            try container.encode(weekDays.map { $0.rawValue }, forKey: .weekDays)
        }
    }
}


struct EventRepeatingMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case start
        case end
        case option
    }
    
    let repeating: EventRepeating
    init(repeating: EventRepeating) {
        self.repeating = repeating
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var repeating = EventRepeating(
            repeatingStartTime: try container.decode(TimeInterval.self, forKey: .start),
            repeatOption: try container.decode(EventRepeatingOptionCodableMapper.self, forKey: .option).option
        )
        repeating.repeatingEndTime = try? container.decode(TimeInterval.self, forKey: .end)
        self.repeating = repeating
    }
    
    func asJson() -> [String: Any] {
        var sender: [String: Any] = [:]
        sender["start"] = self.repeating.repeatingStartTime
        sender["end"] = self.repeating.repeatingEndTime
        sender["option"] = try? EventRepeatingOptionCodableMapper(option: self.repeating.repeatOption).asJson()
        return sender
    }
}
