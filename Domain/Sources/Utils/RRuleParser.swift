//
//  RRuleParser.swift
//  Domain
//
//  Created by sudo.park on 5/24/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - RRule

public struct RRule: Sendable {
    
    public enum Frequency: String, Sendable {
        case DAILY
        case WEEKLY
        case MONTHLY
        case YEARLY
    }
    
    public struct ByDay: Equatable, Sendable {
        
        public enum WeekDay: String, Sendable {
            case MO
            case TU
            case WE
            case TH
            case FR
            case SA
            case SU
        }
        
        public var ordinal: Int?
        public var weekDay: WeekDay
        
        init(ordinal: Int? = nil, weekDay: WeekDay) {
            self.ordinal = ordinal
            self.weekDay = weekDay
        }
        
        init?(text: String) {
            guard text.count >= 2 else { return nil }
            let weekDayString = String(text.suffix(2))
            guard let weekDay = WeekDay(rawValue: weekDayString) else { return nil }
            self.weekDay = weekDay
            
            if text.count > 2 {
                let numString = String(text.prefix(text.count-2))
                self.ordinal = Int(numString)
            }
        }
    }
    
    public let freq: Frequency
    public var interval: Int = 1
    public var byDays: [ByDay] = []
    public var byMonthDays: [Int] = []
    public var byMonths: [Int] = []
    public var until: Date?
    public var count: Int?
    public var unsupportedKeys: [String] = []
}

// MARK: - RFC5545 RRULE parser

public struct RRuleParser: Sendable {

    
    public static func parse(_ recurrence: String) -> RRule? {
        let components = recurrence.components(separatedBy: ":")
        guard components.count == 2,
              let ruleText = components.last,
              let rules = self.splitRules(ruleText),
              let freq = rules["FREQ"].flatMap({ RRule.Frequency(rawValue: $0) })
        else { return nil }
        
        var rule = RRule(freq: freq)
        rules.forEach { key, value in
            switch key {
            case "FREQ":
                break

            case "INTERVAL":
                rule.interval = Int(value) ?? 1

            case "BYDAY":
                let byDays = value.components(separatedBy: ",")
                    .compactMap { RRule.ByDay(text: $0) }
                rule.byDays = byDays

            case "BYMONTHDAY":
                rule.byMonthDays = value.components(separatedBy: ",").compactMap { Int($0) }

            case "BYMONTH":
                rule.byMonths = value.components(separatedBy: ",").compactMap { Int($0) }

            case "UNTIL":
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                rule.until = formatter.date(from: value)

            case "COUNT":
                rule.count = Int(value)

            default:
                rule.unsupportedKeys.append(key)
            }
        }
        return rule
    }
    
    private static func splitRules(_ ruleText: String) -> [String: String]? {

        let components = ruleText.components(separatedBy: ";")
        return components.reduce(into: [String: String]()) { acc, pair in
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                acc[kv[0]] = kv[1]
            }
        }
    }
}

// MARK: - RRule serialization

extension RRule.ByDay {

    fileprivate var asRRuleText: String {
        guard let ordinal = self.ordinal else { return self.weekDay.rawValue }
        return "\(ordinal)\(self.weekDay.rawValue)"
    }
}

extension RRule {

    public func asRRuleText() -> String {
        var parts = ["FREQ=\(self.freq.rawValue)", "INTERVAL=\(self.interval)"]
        if self.byMonths.isEmpty == false {
            parts.append("BYMONTH=\(self.byMonths.map(String.init).joined(separator: ","))")
        }
        if self.byMonthDays.isEmpty == false {
            parts.append("BYMONTHDAY=\(self.byMonthDays.map(String.init).joined(separator: ","))")
        }
        if self.byDays.isEmpty == false {
            parts.append("BYDAY=\(self.byDays.map { $0.asRRuleText }.joined(separator: ","))")
        }
        if let until = self.until {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            parts.append("UNTIL=\(formatter.string(from: until))")
        } else if let count = self.count {
            parts.append("COUNT=\(count)")
        }
        return "RRULE:\(parts.joined(separator: ";"))"
    }
}

// MARK: - recurrence 배열의 RRULE 줄 교체

extension Array where Element == String {

    public func replacingRRuleLine(_ newRRuleText: String?) -> [String] {
        guard self.contains(where: { $0.hasPrefix("RRULE:") }) else {
            guard let newRRuleText else { return self }
            return [newRRuleText] + self
        }
        return self.compactMap { line in
            guard line.hasPrefix("RRULE:") else { return line }
            return newRRuleText
        }
    }
}
