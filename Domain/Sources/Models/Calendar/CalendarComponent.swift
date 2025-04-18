//
//  CalendarComponent.swift
//  Domain
//
//  Created by sudo.park on 2023/06/21.
//

import Foundation
import Prelude
import Optics
import Extensions


public struct CalendarComponent: Equatable {
    
    public struct Week: Equatable {
        public let id: String
        public let days: [Day]
        
        public init(days: [Day]) {
            self.days = days
            self.id = "\(days.first?.identifier ?? "?")-\(days.last?.identifier ?? "?")"
        }
    }
    
    public struct Day: Equatable, Sendable {
        public let year: Int
        public let month: Int
        public let day: Int
        public let weekDay: Int
        public var holidays: [Holiday] = []
        
        public var identifier: String {
            return "\(year)-\(month)-\(day)"
        }
        
        public init(year: Int, month: Int, day: Int, weekDay: Int) {
            self.year = year
            self.month = month
            self.day = day
            self.weekDay = weekDay
        }
        
        public init(_ date: Date, calendar: Calendar) {
            self.year = calendar.component(.year, from: date)
            self.month = calendar.component(.month, from: date)
            self.day = calendar.component(.day, from: date)
            self.weekDay = calendar.component(.weekday, from: date)
        }
        
        public func dayRange(_ timeZone: TimeZone) -> Range<TimeInterval>? {
            let calendar = Calendar(identifier: .gregorian)
            |> \.timeZone .~ timeZone
            guard let date = calendar.date(from: self),
                  let range = calendar.dayRange(date)
            else { return nil }
            return range
        }
    }
    
    public let year: Int
    public let month: Int
    public var weeks: [Week]
    
    public func holiday(_ month: Int, _ day: Int) -> [Holiday]? {
        return self.weeks
            .flatMap { $0.days }
            .first(where: { $0.month == month && $0.day == day })?
            .holidays
    }
    
    public init(year: Int, month: Int, weeks: [Week]) {
        self.year = year
        self.month = month
        self.weeks = weeks
    }
    
    public func update(holidays: [Holiday]) -> CalendarComponent {
        let holidayMap = holidays.reduce(into: [String: [Holiday]]()) {
            $0[$1.dateString] = ($0[$1.dateString] ?? []) + [$1]
        }
        let newWeeks = self.weeks.map { week -> Week in
            let newDays = week.days.map { day -> Day in
                let dateString = "\(day.year)-\(day.month.withLeadingZero())-\(day.day.withLeadingZero())"
                return day |> \.holidays .~ (holidayMap[dateString] ?? [])
            }
            return .init(days: newDays)
        }
        return .init(year: self.year, month: self.month, weeks: newWeeks)
    }
}


extension Calendar {
    
    public func date(from day: CalendarComponent.Day) -> Date? {
        let components = DateComponents(
            year: day.year, month: day.month, day: day.day,
            hour: 0, minute: 0, second: 0
        )
        return self.date(from: components)
    }
}
