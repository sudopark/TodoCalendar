//
//  MonthWidgetViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation


// MARK: - MonthWidgetViewModel

public struct MonthWidgetViewModel {
    public let anchorDay: CalendarDay
    public let monthName: String
    public let dayOfWeeksModels: [WeekDayModel]
    public let weeks: [WeekRowModel]
    public var todayIdentifier: String?
    public var hasEventDaysIdentifiers: Set<String> = []
    public var widgetSetting = WidgetAppearanceSettings()
    
    public internal(set) var eventRange: Range<TimeInterval>?
    
    public init(
        _ date: Date,
        _ firstWeekDay: DayOfWeeks,
        _ timeZone: TimeZone,
        _ component: CalendarComponent,
        _ todayIdentifier: String?
    ) {
        self.dayOfWeeksModels = WeekDayModel.allModels(of: firstWeekDay)
        self.weeks = component.weeks.map { week in
            return .init(week, month: component.month)
        }
        
        self.todayIdentifier = todayIdentifier
        let formatter = DateFormatter() |> \.dateFormat .~ "date_form.MMM".localized()
        self.monthName = formatter.string(from: date)
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        self.anchorDay = .init(
            calendar.component(.year, from: date),
            calendar.component(.month, from: date),
            calendar.component(.day, from: date)
        )
        guard let first = component.weeks.first?.days.first,
              let start = calendar.dateBySetting(from: date, mutating: {
                  $0.year = first.year; $0.month = first.month; $0.day = first.day
              }),
              let last = component.weeks.last?.days.last,
              let end = calendar.dateBySetting(from: date, mutating: {
                  $0.year = last.year; $0.month = last.month; $0.day = last.day
              }),
              let endTime = calendar.endOfDay(for: end)
        else { return }
        let startTime = calendar.startOfDay(for: start)
        self.eventRange = (startTime.timeIntervalSince1970..<endTime.timeIntervalSince1970)
    }
    
    public static func makeSample() throws -> MonthWidgetViewModel {
        let calendar = Calendar(identifier: .gregorian)
        let today = try calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 3; $0.day = 10
        }.unwrap()
        let weekAndDays: [[(Int, Int)]] = [
            [(2, 25), (2, 26), (2, 27), (2, 28), (2, 29), (3, 1), (3, 2)],
            [(3, 3), (3, 4), (3, 5), (3, 6), (3, 7), (3, 8), (3, 9)],
            [(3, 10), (3, 11), (3, 12), (3, 13), (3, 14), (3, 15), (3, 16)],
            [(3, 17), (3, 18), (3, 19), (3, 20), (3, 21), (3, 22), (3, 23)],
            [(3, 24), (3, 25), (3, 26), (3, 27), (3, 28), (3, 29), (3, 30)],
            [(3, 31), (4, 1), (4, 2), (4, 3), (4, 4), (4, 5), (4, 6)]
        ]
        let weeks = weekAndDays.map { pairs -> CalendarComponent.Week in
            let days = pairs.enumerated().map { offset, pair -> CalendarComponent.Day in
                return .init(year: 2024, month: pair.0, day: pair.1, weekDay: offset+1)
            }
            return CalendarComponent.Week(days: days)
        }
        let components = CalendarComponent(year: 2024, month: 3, weeks: weeks)
        return MonthWidgetViewModel(today, .sunday, .current, components, "2024-3-10")
            |> \.hasEventDaysIdentifiers .~ [
                "2024-3-4", "2024-3-17", "2024-3-28"
            ]
    }
    
    public static func makeSampleNextMonth() throws -> MonthWidgetViewModel {
        let calendar = Calendar(identifier: .gregorian)
        let refDate = try calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 4; $0.day = 10
        }.unwrap()
        let weekAndDays: [[(Int, Int)]] = [
            [(3, 31), (4, 1), (4, 2), (4, 3), (4, 4), (4, 5), (4, 6)],
            [(4, 7), (4, 8), (4, 9), (4, 10), (4, 11), (4, 12), (4, 13)],
            [(4, 14), (4, 15), (4, 16), (4, 17), (4, 18), (4, 19), (4, 20)],
            [(4, 21), (4, 22), (4, 23), (4, 24), (4, 25), (4, 26), (4, 27)],
            [(4, 28), (4, 29), (4, 30), (5, 1), (5, 2), (5, 3), (5, 4)]
        ]
        let weeks = weekAndDays.map { pairs -> CalendarComponent.Week in
            let days = pairs.enumerated().map { offset, pair -> CalendarComponent.Day in
                return .init(year: 2024, month: pair.0, day: pair.1, weekDay: offset+1)
            }
            return CalendarComponent.Week(days: days)
        }
        let components = CalendarComponent(year: 2024, month: 4, weeks: weeks)
        return MonthWidgetViewModel(refDate, .sunday, .current, components, nil)
    }
}
