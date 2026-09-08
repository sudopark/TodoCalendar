//
//  MonthDisplayModels.swift
//  CalendarScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - week components

public struct WeekDayModel: Equatable {
    public let symbol: String
    public let isSunday: Bool
    public let isSaturday: Bool
    public let identifier: String
    
    public init(symbol: String, _ identifier: String, isSunday: Bool = false, isSaturday: Bool = false) {
        self.symbol = symbol
        self.identifier = identifier
        self.isSunday = isSunday
        self.isSaturday = isSaturday
    }
    
    public static func allModels() -> [WeekDayModel] {
        return [
            .init(symbol: R.String.daynameSundayVeryShort, "sunday", isSunday: true),
            .init(symbol: R.String.daynameMondayVeryShort, "moday"),
            .init(symbol: R.String.daynameTuesdayVeryShort, "tuesday"),
            .init(symbol: R.String.daynameWednesdayVeryShort, "wednesday"),
            .init(symbol: R.String.daynameThursdayVeryShort, "thursday"),
            .init(symbol: R.String.daynameFridayVeryShort, "friday"),
            .init(symbol: R.String.daynameSaturdayVeryShort, "saturday", isSaturday: true)
        ]
    }
    
    public static func allModels(of firstWeekDay: DayOfWeeks) -> [WeekDayModel] {
        let models = self.allModels()
        let startIndex = firstWeekDay.rawValue-1
        return (startIndex..<startIndex+7).map { index in
            return models[index % 7]
        }
    }
}

public struct DayCellViewModel: Equatable {
    
    public let year: Int
    public let month: Int
    public let day: Int
    public let isNotCurrentMonth: Bool
    public var accentDay: AccentDays?
    
    public init(
        year: Int,
        month: Int,
        day: Int,
        isNotCurrentMonth: Bool,
        accentDay: AccentDays?
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.isNotCurrentMonth = isNotCurrentMonth
        self.accentDay = accentDay
    }
    
    public var identifier: String {
        "\(year)-\(month)-\(day)"
    }
    
    public init(_ day: CalendarComponent.Day, month: Int) {
        self.year = day.year
        self.month = day.month
        self.day = day.day
        self.isNotCurrentMonth = day.month != month
        let dayOfWeek = DayOfWeeks(rawValue: day.weekDay)
        switch (dayOfWeek, !day.holidays.isEmpty ) {
        case (_, true):
            self.accentDay = .holiday
        case (.sunday, _):
            self.accentDay = .sunday
        case (.saturday, _):
            self.accentDay = .saturday
        default:
            self.accentDay = nil
        }
    }
}

public struct WeekRowModel: Equatable {
    public let id: String
    public var days: [DayCellViewModel]
    
    public init(_ id: String, _ days: [DayCellViewModel]) {
        self.id = id
        self.days = days
    }
    
    public init(_ week: CalendarComponent.Week, month: Int) {
        self.id = week.id
        self.days = week.days.map { day -> DayCellViewModel in
            return .init(day, month: month)
        }
    }
}

public struct EventMoreModel: Equatable {
    public let daySequence: Int
    public let moreCount: Int
    
    public init(daySequence: Int, moreCount: Int) {
        self.daySequence = daySequence
        self.moreCount = moreCount
    }
}

public struct WeekEventStackViewModel: Equatable {
    public let linesStack: [[EventOnWeek]]
    public var shouldShowEventLinesDays: Set<Int> = []
    
    public init(linesStack: [[EventOnWeek]], shouldMarkEventDays: Bool) {
        self.linesStack = linesStack
        guard shouldMarkEventDays else { return }
        self.shouldShowEventLinesDays = linesStack.flatMap { $0 }
            .filter { !($0.event is HolidayCalendarEvent) }
            .reduce(Set<Int>()) { acc, line in acc.union(line.overlapDays) }
    }
}

extension WeekEventStackViewModel {
    
    public func eventMores(with maxSize: Int) -> [EventMoreModel] {
        guard maxSize > 0, maxSize < self.linesStack.count else { return [] }
        let willHiddenRows = self.linesStack[maxSize...]
        let willHiddenEventsPerDaySeq = willHiddenRows.reduce(into: [Int: [EventOnWeek]]()) { acc, lines in
            lines.forEach { line in
                line.daysSequence.forEach {
                    acc[$0] = (acc[$0] ?? []) + [line]
                }
            }
        }
        return willHiddenEventsPerDaySeq.map {
            return EventMoreModel(
                daySequence: $0.key,
                moreCount: $0.value.count
            )
        }
    }
}
