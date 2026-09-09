//
//  WeekEventsViewModel.swift
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


public enum WeekEventsRange: Sendable {
    
    public enum SelectedMonth: Sendable {
        case previous
        case current
        case next
    }
    
    case weeks(count: Int)
    case wholeMonth(SelectedMonth)
}


public struct WeekEventsViewModel {
    
    public let range: WeekEventsRange
    public let targetMonthText: String
    public let targetDayIndetifier: String
    public let orderedWeekDaysModel: [WeekDayModel]
    public let weeks: [WeekRowModel]
    public let eventStackModelMap: [String: WeekEventStackViewModel]
    public let defaultTagColorSetting: DefaultEventTagColorSetting
    public let tagMap: [String: CustomEventTag]
    public var googleCalendarColor: GoogleCalendar.Colors?
    public var googleCalendarTags: [String: GoogleCalendar.Tag]
    public var appleCalendarTags: [String: AppleCalendar.Tag]
    public var widgetSetting: WidgetAppearanceSettings
    
    public init(
        range: WeekEventsRange,
        targetMonthText: String,
        targetDayIndetifier: String,
        orderedWeekDaysModel: [WeekDayModel],
        weeks: [WeekRowModel],
        eventStackModelMap: [String : WeekEventStackViewModel],
        defaultTagColorSetting: DefaultEventTagColorSetting,
        tagMap: [String: CustomEventTag],
        googleCalendarColor: GoogleCalendar.Colors? = nil,
        googleCalendarTags: [String: GoogleCalendar.Tag] = [:],
        appleCalendarTags: [String: AppleCalendar.Tag] = [:],
        widgetSetting: WidgetAppearanceSettings
    ) {
        self.range = range
        self.targetMonthText = targetMonthText
        self.targetDayIndetifier = targetDayIndetifier
        self.orderedWeekDaysModel = orderedWeekDaysModel
        self.weeks = weeks
        self.eventStackModelMap = eventStackModelMap
        self.defaultTagColorSetting = defaultTagColorSetting
        self.tagMap = tagMap
        self.googleCalendarColor = googleCalendarColor
        self.googleCalendarTags = googleCalendarTags
        self.appleCalendarTags = appleCalendarTags
        self.widgetSetting = widgetSetting
    }
    
    public static func sample(_ range: WeekEventsRange) -> WeekEventsViewModel {
        switch range {
        case .weeks(let count):
            return self.weeksSample(count)
        case .wholeMonth(let selection):
            return self.wholeMonthSample(selection)
        }
    }
    
    private static func weeksSample(_ count: Int) -> WeekEventsViewModel {
        let wholeModel = self.wholeMonthSample(.current)
        let size = min(count, wholeModel.weeks.count)
        let startPoint = count <= 2 ? 2 : 1
        let sliced = Array(wholeModel.weeks[startPoint..<startPoint+size])
        return .init(
            range: .weeks(count: count),
            targetMonthText: wholeModel.targetMonthText,
            targetDayIndetifier: wholeModel.targetDayIndetifier,
            orderedWeekDaysModel: wholeModel.orderedWeekDaysModel,
            weeks: sliced,
            eventStackModelMap: wholeModel.eventStackModelMap,
            defaultTagColorSetting: .init(holiday: "#D6236A", default: "#088CDA"),
            tagMap: [:],
            widgetSetting: .init()
        )
    }
    
    private static func wholeMonthSample(_ selection: WeekEventsRange.SelectedMonth) -> WeekEventsViewModel {
        let targetMonth = switch selection {
        case .previous: (2, "widget.weeks.sample::feb".localized())
        case .current: (3, "widget.weeks.sample::march".localized())
        case .next: (4, "widget.weeks.sample::april".localized())
        }
        let targetDate = "2024-3-14"
        let weekAndDays: [[(Int, Int)]] = switch selection {
        case .previous: [
            [(1, 31), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5), (2, 6)],
            [(2, 7), (2, 8), (2, 9), (2, 10), (2, 11), (2, 12), (2, 13)],
            [(2, 14), (2, 15), (2, 16), (2, 17), (2, 18), (2, 19), (2, 20)],
            [(2, 21), (2, 22), (2, 23), (2, 24), (2, 25), (2, 26), (2, 27)],
            [(2, 28), (3, 1), (3, 2), (3, 3), (3, 4), (3, 5), (3, 6)]
        ]
        case .current: [
            [(2, 28), (3, 1), (3, 2), (3, 3), (3, 4), (3, 5), (3, 6)],
            [(3, 7), (3, 8), (3, 9), (3, 10), (3, 11), (3, 12), (3, 13)],
            [(3, 14), (3, 15), (3, 16), (3, 17), (3, 18), (3, 19), (3, 20)],
            [(3, 21), (3, 22), (3, 23), (3, 24), (3, 25), (3, 26), (3, 27)],
            [(3, 28), (3, 29), (3, 30), (3, 31), (4, 1), (4, 2), (4, 3)]
        ]
        case .next: [
            [(3, 28), (3, 29), (3, 30), (3, 31), (4, 1), (4, 2), (4, 3)],
            [(4, 4), (4, 5), (4, 6), (4, 7), (4, 8), (4, 9), (4, 10)],
            [(4, 11), (4, 12), (4, 13), (4, 14), (4, 15), (4, 16), (4, 17)],
            [(4, 18), (4, 19), (4, 20), (4, 21), (4, 22), (4, 23), (4, 24)],
            [(4, 25), (4, 26), (4, 27), (4, 28), (4, 29), (4, 30), (5, 1)]
        ]
        }
        let rowModels = weekAndDays.enumerated().map { weekOffset, week -> WeekRowModel in
            let weekId = "\(targetMonth.0)-\(weekOffset)"
            let days = week.enumerated().map { offset, pair -> DayCellViewModel in
                let day = CalendarComponent.Day(
                    year: 2024, month: pair.0, day: pair.1, weekDay: offset+1
                )
                let accentDay: AccentDays? = if day.month == 3 && day.day == 20 {
                    .holiday
                } else if day.weekDay == 1 {
                    .sunday
                } else if day.weekDay == 7 {
                    .saturday
                } else { nil }
                return DayCellViewModel(day, month: targetMonth.0)
                |> \.accentDay .~ accentDay
            }
            return WeekRowModel(weekId, days)
        }
        let eventStacks: [String: WeekEventStackViewModel] = [
            "2-1": .init(linesStack: [
                [.dummy(5, "2024-02-11", "widget.weeks.sample::hiking".localized())]
            ], shouldMarkEventDays: false),
            "3-2": .init(linesStack: [
                [
                    .dummy(1, "2024-03-14", "widget.weeks.sample::lunch".localized()),
                    .dummy(3, "2024-03-16", "widget.weeks.sample::call".localized()),
                    .dummy(7, "2024-03-20", "widget.weeks.sample::holiday".localized(), hasPeriod: true, tag: .holiday)
                ],
                [.dummy(1, "2024-03-14", "widget.weeks.sample::golf".localized())],
            ], shouldMarkEventDays: false),
            "3-3": .init(linesStack: [
                [.dummy(4, "2024-03-25", "widget.weeks.sample::workout".localized())]
            ], shouldMarkEventDays: false),
            "4-3": .init(linesStack: [
                [.dummy(7, "2024-04-24", "widget.weeks.sample::launch".localized())]
            ], shouldMarkEventDays: false)
        ]
        
        return .init(
            range: .wholeMonth(selection),
            targetMonthText: targetMonth.1,
            targetDayIndetifier: targetDate,
            orderedWeekDaysModel: WeekDayModel.allModels(),
            weeks: rowModels,
            eventStackModelMap: eventStacks,
            defaultTagColorSetting: .init(holiday: "#D6236A", default: "#088CDA"),
            tagMap: [:],
            widgetSetting: .init()
        )
    }
}


private extension EventOnWeek {
    
    static func dummy(
        _ dayNumber: Int, _ dateId: String,
        _ name: String, hasPeriod: Bool = false, tag: EventTagId = .default
    ) -> EventOnWeek {
        let event = DummyCalendarEvent(name, name, hasPeriod: hasPeriod, tag: tag)
        return EventOnWeek(0..<1, [dayNumber], (dayNumber...dayNumber), [dateId], event)
    }
}


private struct DummyCalendarEvent: CalendarEvent {
    var eventId: String
    var name: String
    var eventTime: EventTime?
    var eventTimeOnCalendar: EventTimeOnCalendar?
    var eventTagId: EventTagId
    var isRepeating: Bool = false
    var isForemost: Bool = false
    var locationText: String?

    init(_ id: String, _ name: String, hasPeriod: Bool = true, tag: EventTagId = .default) {
        self.eventId = id
        self.name = name
        self.eventTagId = tag
        if hasPeriod {
            self.eventTimeOnCalendar = .init(.period(0..<1), timeZone: TimeZone.autoupdatingCurrent)
        }
    }
}
