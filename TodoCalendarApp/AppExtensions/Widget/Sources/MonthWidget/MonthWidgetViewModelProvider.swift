//
//  MonthWidgetUsecase.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - MonthWidgetViewModel

struct MonthWidgetViewModel {
    let monthName: String
    let dayOfWeeksModels: [WeekDayModel]
    let weeks: [WeekRowModel]
    let todayIdentifier: String
    var hasEventDaysIdentifiers: Set<String> = []
    
    fileprivate var eventRange: Range<TimeInterval>?
    
    init(
        _ date: Date,
        _ firstWeekDay: DayOfWeeks,
        _ timeZone: TimeZone,
        _ component: CalendarComponent,
        _ todayIdentifier: String
    ) {
        self.dayOfWeeksModels = WeekDayModel.allModels(of: firstWeekDay)
        self.weeks = component.weeks.map { week in
            return .init(week, month: component.month)
        }
        
        self.todayIdentifier = todayIdentifier
        let formatter = DateFormatter() |> \.dateFormat .~ "MMM".localized()
        self.monthName = formatter.string(from: date)
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
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
}


// MARK: - MonthWidgetViewModelProvider

protocol MonthWidgetViewModelProvider {
    
    func makeSampleMonthViewModel(_ now: Date) throws -> MonthWidgetViewModel
    
    func getMonthViewModel(_ now: Date) async throws -> MonthWidgetViewModel
}

final class MonthWidgetViewModelProviderImple: MonthWidgetViewModelProvider {
    
    private let calendarUsecase: any CalendarUsecase
    private let settingRepository: any CalendarSettingRepository
    private let todoRepository: any TodoEventRepository
    private let scheduleRepository: any ScheduleEventRepository
    
    init(
        calendarUsecase: any CalendarUsecase,
        settingRepository: any CalendarSettingRepository,
        todoRepository: any TodoEventRepository,
        scheduleRepository: any ScheduleEventRepository
    ) {
        self.calendarUsecase = calendarUsecase
        self.settingRepository = settingRepository
        self.todoRepository = todoRepository
        self.scheduleRepository = scheduleRepository
    }
}

extension MonthWidgetViewModelProviderImple {
    
    func makeSampleMonthViewModel(_ now: Date) throws -> MonthWidgetViewModel {
        let components = try self.calendarUsecase.getComponents(2024, 03, .sunday)
        let calendar = Calendar(identifier: .gregorian)
        let today = try calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 3; $0.day = 10
        }.unwrap()
        return MonthWidgetViewModel(today, .sunday, .current, components, "2024-3-10")
            |> \.hasEventDaysIdentifiers .~ [
                "2024-3-4", "2024-3-17", "2024-3-28"
            ]
    }
    
    func getMonthViewModel(_ now: Date) async throws -> MonthWidgetViewModel {
        let timeZone = self.settingRepository.loadUserSelectedTImeZone() ?? .current
        var model = try self.currentMonthModel(now, timeZone)
        if let ranges = model.eventRange {
            model.hasEventDaysIdentifiers = await self.loadEventExistsDayIdentifiers(
                ranges, timeZone
            )
        }
        return model
    }
    
    private func currentMonthModel(_ now: Date, _ timeZone: TimeZone) throws -> MonthWidgetViewModel {
        let firstWeekDay = self.settingRepository.firstWeekDay() ?? .sunday
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let today = CalendarComponent.Day(now, calendar: calendar)
        let components = try self.calendarUsecase.getComponents(
            calendar.component(.year, from: now),
            calendar.component(.month, from: now),
            firstWeekDay
        )
        return .init(now, firstWeekDay, timeZone, components, today.identifier)
    }
    
    private func loadEventExistsDayIdentifiers(
        _ range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async -> Set<String> {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todos = try? await todoRepository.loadTodoEvents(in: range)
            .values.first(where: { _ in true })
        let schedules = try? await scheduleRepository.loadScheduleEvents(in: range)
            .values.first(where: { _ in true })
        let allEventTimes = (todos?.compactMap { $0.time } ?? []) + (schedules?.map { $0.time } ?? [])
        let identifiers = allEventTimes
            .map { EventTimeOnCalendar($0, timeZone: timeZone) }
            .compactMap { $0.clamped(to: range) }
            .map { calendar.daysIdentifiers($0) }
        return Set(identifiers.flatMap { $0 })
    }
}
