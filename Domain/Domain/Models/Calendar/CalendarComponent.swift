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
        public let days: [Day]
        
        public init(days: [Day]) {
            self.days = days
        }
    }
    
    public struct Day: Equatable {
        public let year: Int
        public let month: Int
        public let day: Int
        public let weekDay: Int
        public var holiday: Holiday?
        
        public init(year: Int, month: Int, day: Int, weekDay: Int) {
            self.year = year
            self.month = month
            self.day = day
            self.weekDay = weekDay
        }
        
        init(_ date: Date, calendar: Calendar) {
            self.year = calendar.component(.year, from: date)
            self.month = calendar.component(.month, from: date)
            self.day = calendar.component(.day, from: date)
            self.weekDay = calendar.component(.weekday, from: date)
        }
    }
    
    public let year: Int
    public let month: Int
    public var weeks: [Week]
    
    public init(year: Int, month: Int, weeks: [Week]) {
        self.year = year
        self.month = month
        self.weeks = weeks
    }
    
    public func update(holidays: [Holiday]) -> CalendarComponent {
        let holidayMap = holidays.reduce(into: [String: Holiday]()) { $0[$1.dateString] = $1 }
        let newWeeks = self.weeks.map { week -> Week in
            let newDays = week.days.map { day -> Day in
                let dateString = "\(day.year)-\(day.month.withLeadingZero())-\(day.day.withLeadingZero())"
                return day |> \.holiday .~ holidayMap[dateString]
            }
            return .init(days: newDays)
        }
        return .init(year: self.year, month: self.month, weeks: newWeeks)
    }
}
