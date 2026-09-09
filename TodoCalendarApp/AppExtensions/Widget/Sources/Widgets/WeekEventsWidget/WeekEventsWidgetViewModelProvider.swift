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
import CalendarPresentation
import WidgetScenes


// MARK: - WeeksWithRange

private struct WeeksWithRange {
    let weeks: [CalendarComponent.Week]
    let range: Range<TimeInterval>

    init(_ weeks: [CalendarComponent.Week], _ timeZone: TimeZone) throws {
        self.weeks = weeks
        guard let firstWeekRange = weeks.first?.range(timeZone),
              let lastWeekRange = weeks.last?.range(timeZone)
        else { throw RuntimeError("invalid period") }
        self.range = firstWeekRange.lowerBound..<lastWeekRange.upperBound
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
        let appearSetting = self.appSettingRepository.loadSavedViewAppearance()
        let defaultTagColorSetting = appearSetting.defaultTagColor
        let calenar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let targetMonthDate = calenar.targetMonthRefDate(date, for: range)
        let targetMonth = calenar.component(.month, from: targetMonthDate)
        let weeks = try self.getWeeks(date, firstWeekDay, range, calenar)
        let events = try await self.eventFetchUsecase.fetchEvents(in: weeks.range, timeZone, withoutOffTagIds: true)
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
            googleCalendarTags: events.googleCalendarTags,
            appleCalendarTags: events.appleCalendarTags,
            widgetSetting: appearSetting.widget
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
        
        return try WeeksWithRange(weeks, calendar.timeZone)
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
