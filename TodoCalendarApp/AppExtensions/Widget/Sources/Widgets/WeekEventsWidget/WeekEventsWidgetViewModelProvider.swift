//
//  WeekEventsWidgetViewModelProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/30/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - WeekEventsViewModel

enum WeekEventsRange {
    
    enum SelectedMonth {
        case previous
        case current
        case next
    }
    
    case weeks(count: Int)
    case wholeMonth(SelectedMonth)
}

private struct WeeksWithRange {
    let weeks: [CalendarComponent.Week]
    let range: Range<TimeInterval>
    
    init(_ weeks: [CalendarComponent.Week], _ calendar: Calendar) throws {
        self.weeks = weeks
        guard let startDay = weeks.first?.days.first,
              let endDay = weeks.last?.days.last,
              let startDate = calendar.date(from: startDay),
              let endDate = calendar.date(from: endDay)
        else { throw RuntimeError("invalid period") }
        let startTime = calendar.startOfDay(for: startDate)
        let endTime = try calendar.endOfDay(for: endDate).unwrap()
        self.range = startTime.timeIntervalSince1970..<endTime.timeIntervalSince1970
    }
}

struct WeekEventsViewModel {
    
    let range: WeekEventsRange
    let targetMonthText: String
    let targetDayIndetifier: String
    let orderedWeekDaysModel: [WeekDayModel]
    let weeks: [WeekRowModel]
    let eventStackModelMap: [String: WeekEventStackViewModel]
    let defaultTagColorSetting: DefaultEventTagColorSetting
    let tagMap: [String: CustomEventTag]
    var googleCalendarColor: GoogleCalendar.Colors?
    var googleCalendarTags: [String: GoogleCalendar.Tag]
    
    init(
        range: WeekEventsRange,
        targetMonthText: String,
        targetDayIndetifier: String,
        orderedWeekDaysModel: [WeekDayModel],
        weeks: [WeekRowModel],
        eventStackModelMap: [String : WeekEventStackViewModel],
        defaultTagColorSetting: DefaultEventTagColorSetting,
        tagMap: [String: CustomEventTag],
        googleCalendarColor: GoogleCalendar.Colors? = nil,
        googleCalendarTags: [String: GoogleCalendar.Tag] = [:]
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
    }
    
    static func sample(_ range: WeekEventsRange) -> WeekEventsViewModel {
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
            tagMap: [:]
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
            tagMap: [:]
        )
    }
}

final class WeekEventsWidgetViewModelProvider {
    
    private let calendarUsecase: any CalendarUsecase
    private let eventFetchUsecase: any CalendarEventFetchUsecase
    private let settingRepository: any CalendarSettingRepository
    private let appSettingRepository: any AppSettingRepository
    
    init(
        calendarUsecase: any CalendarUsecase,
        eventFetchUsecase: any CalendarEventFetchUsecase,
        settingRepository: any CalendarSettingRepository,
        appSettingRepository: any AppSettingRepository
    ) {
        self.calendarUsecase = calendarUsecase
        self.eventFetchUsecase = eventFetchUsecase
        self.settingRepository = settingRepository
        self.appSettingRepository = appSettingRepository
    }
}

extension WeekEventsWidgetViewModelProvider {
    
    func getWeekEventsModel(
        from date: Date, range: WeekEventsRange
    ) async throws -> WeekEventsViewModel {
        
        let timeZone = self.settingRepository.loadUserSelectedTImeZone() ?? .current
        let firstWeekDay = self.settingRepository.firstWeekDay() ?? .sunday
        let defaultTagColorSetting = self.appSettingRepository.loadSavedViewAppearance().defaultTagColor
        let calenar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let targetMonthDate = calenar.targetMonthRefDate(date, for: range)
        let targetMonth = calenar.component(.month, from: targetMonthDate)
        let weeks = try self.getWeeks(date, firstWeekDay, range, calenar)
        let events = try await self.eventFetchUsecase.fetchEvents(in: weeks.range, timeZone)
        let targetDate = CalendarComponent.Day(date, calendar: calenar)
        
        return WeekEventsViewModel(
            range: range,
            targetMonthText: targetMonthDate.text("date_form.MMMM".localized(), timeZone: timeZone).uppercased(),
            targetDayIndetifier: targetDate.identifier,
            orderedWeekDaysModel: WeekDayModel.allModels(of: firstWeekDay),
            weeks: self.convertToWeekRowModels(weeks, events.eventWithTimes, targetMonth),
            eventStackModelMap: self.convertToEventStackModelMap(events, weeks.weeks, timeZone),
            defaultTagColorSetting: defaultTagColorSetting,
            tagMap: events.customTagMap,
            googleCalendarColor: events.googleCalendarColors,
            googleCalendarTags: events.googleCalendarTags
        )
    }
    
    private func getWeeks(
        _ date: Date,
        _ firstWeekDay: DayOfWeeks,
        _ range: WeekEventsRange,
        _ calendar: Calendar
    ) throws -> WeeksWithRange {
        
        func selectWeeks(_ count: Int) throws -> [CalendarComponent.Week] {
            let start = try calendar.firstDateOfWeek(firstWeekDay, date).unwrap()
            let getDays: (Int) throws -> [CalendarComponent.Day] = { weekOffset in
                let weekStart = try calendar.addDays(7*weekOffset, from: start).unwrap()
                return try (0..<7).map { offset in
                    let date = try calendar.addDays(offset, from: weekStart).unwrap()
                    return .init(date, calendar: calendar)
                }
            }
            let weeks = try (0..<count).map { weekOffset in
                let days = try getDays(weekOffset)
                return CalendarComponent.Week(days: days)
            }
            return weeks
        }
        func wholeWeeks(_ select: WeekEventsRange.SelectedMonth) throws -> [CalendarComponent.Week] {
            let offset = switch select {
            case .previous: -1
            case .current: 0
            case .next: 1
            }
            let refDate = try calendar.addMonth(offset, from: date).unwrap()
            let day = CalendarComponent.Day(refDate, calendar: calendar)
            let component = try self.calendarUsecase.getComponents(
                day.year, day.month, firstWeekDay
            )
            return component.weeks
        }
        
        let weeks = switch range {
        case .weeks(let count): try selectWeeks(count)
        case .wholeMonth(let selection): try wholeWeeks(selection)
        }
        
        return try WeeksWithRange(weeks, calendar)
    }
    
    private func convertToWeekRowModels(
        _ weeks: WeeksWithRange, _ events: [any CalendarEvent], _ targetMonth: Int
    ) -> [WeekRowModel] {
        let weekModels = weeks.weeks.map { WeekRowModel($0, month: targetMonth) }
        let holidaysMap = events.compactMap { $0 as? HolidayCalendarEvent }.asDictionary { $0.dateString }
        let weekModelsWithHoliday = weekModels.map { week -> WeekRowModel in
            let days = week.days.map { model -> DayCellViewModel in
                let holidayKey = "\(model.year)-\(model.month.withLeadingZero())-\(model.day.withLeadingZero())"
                let hasHoliday = holidaysMap[holidayKey] != nil
                return model |> \.accentDay .~ (hasHoliday ? .holiday : model.accentDay)
            }
            return week |> \.days .~ days
        }
        return weekModelsWithHoliday
    }
    
    private func convertToEventStackModelMap(
        _ events: CalendarEvents,
        _ weeks: [CalendarComponent.Week],
        _ timeZone: TimeZone
    ) -> [String: WeekEventStackViewModel] {
        let stackBuilder = WeekEventStackBuilder(timeZone)
        let stackMap = weeks.reduce(into: [String: WeekEventStack]()) { acc, week in
            let stack = stackBuilder.build(week, events: events.eventWithTimes)
            acc[week.id] = stack
        }
        
        let stackModelMap = stackMap.mapValues { stack in
            return WeekEventStackViewModel(linesStack: stack.eventStacks, shouldMarkEventDays: false)
        }
        return stackModelMap
    }
}


private extension Calendar {
    
    func targetMonthRefDate(_ date: Date, for range: WeekEventsRange) -> Date {
        switch range {
        case .weeks: return date
        case .wholeMonth(.current): return date
        case .wholeMonth(.previous): return self.addMonth(-1, from: date) ?? date
        case .wholeMonth(.next): return self.addMonth(1, from: date) ?? date
        }
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

    init(_ id: String, _ name: String, hasPeriod: Bool = true, tag: EventTagId = .default) {
        self.eventId = id
        self.name = name
        self.eventTagId = tag
        if hasPeriod {
            self.eventTimeOnCalendar = .init(.period(0..<1), timeZone: TimeZone.autoupdatingCurrent)
        }
    }
}
