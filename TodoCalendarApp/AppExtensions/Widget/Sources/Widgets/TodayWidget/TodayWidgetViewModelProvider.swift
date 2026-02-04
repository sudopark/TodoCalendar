//
//  TodayWidgetViewModelProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - TodayWidgetViewModel

struct TodayWidgetViewModel {
    
    let id: CalendarDay
    let weekDayText: String
    let day: Int
    var holidayName: String?
    var isHoliday: Bool { self.holidayName != nil }
    let monthAndYearText: String
    var timeZoneText: String?
    var todoEventCount: Int = 0
    var scheduleEventcount: Int = 0
    var totalEventCount: Int { self.todoEventCount + self.scheduleEventcount }
    var widgetSetting = WidgetAppearanceSettings()
    
    init(
        id: CalendarDay,
        weekDayText: String,
        day: Int,
        monthAndYearText: String
    ) {
        self.id = id
        self.weekDayText = weekDayText
        self.day = day
        self.monthAndYearText = monthAndYearText
    }
    
    init(_ today: Date, _ calendar: Calendar) {
        self.id = .init(
            calendar.component(.year, from: today),
            calendar.component(.month, from: today),
            calendar.component(.day, from: today)
        )
        let timeZone = calendar.timeZone
        self.weekDayText = today.text("date_form.EEEE".localized(), timeZone: timeZone).uppercased()
        self.day = calendar.component(.day, from: today)
        self.monthAndYearText = today.text("date_form.MMM_yyyy".localized(), timeZone: timeZone).uppercased()
        if timeZone != TimeZone.current {
            self.timeZoneText = timeZone.localizedName(for: .shortStandard, locale: .current)
        }
    }
    
    func updated(events: CalendarEvents) -> TodayWidgetViewModel {
        let holiday = events.eventWithTimes.compactMap { $0 as? HolidayCalendarEvent }.first
        let todoCount = events.currentTodos.count + events.eventWithTimes.filter { $0 is TodoCalendarEvent }.count
        let scheduleCount = events.eventWithTimes.filter { $0 is ScheduleCalendarEvent }.count
        return self
            |> \.holidayName .~ holiday?.name
            |> \.todoEventCount .~ todoCount
            |> \.scheduleEventcount .~ scheduleCount
    }
    
    static func sample() -> TodayWidgetViewModel {
        return .init(
            id: .init(2024, 03, 14),
            weekDayText: "widget.events.today::sample::sunday".localized(),
            day: 14,
            monthAndYearText: "widget.events.today::sample::march2024".localized()
        )
        |> \.todoEventCount .~ 3
        |> \.scheduleEventcount .~ 4
    }
}


final class TodayWidgetViewModelProvider {
    
    private let eventsFetchusecase: any CalendarEventFetchUsecase
    private let appSettingRepository: any AppSettingRepository
    private let calednarSettingRepository: any CalendarSettingRepository
    
    init(
        eventsFetchusecase: any CalendarEventFetchUsecase,
        appSettingRepository: any AppSettingRepository,
        calednarSettingRepository: any CalendarSettingRepository
    ) {
        self.eventsFetchusecase = eventsFetchusecase
        self.appSettingRepository = appSettingRepository
        self.calednarSettingRepository = calednarSettingRepository
    }
}

extension TodayWidgetViewModelProvider {
    
    
    func getTodayViewModel(for today: Date) async throws -> TodayWidgetViewModel {
        
        let setting = self.appSettingRepository.loadWidgetAppearanceSetting()
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let calednar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calednar.dayRange(today).unwrap()
        let events = try await self.todayEvents(todayRange, timeZone)
        return TodayWidgetViewModel(today, calednar)
            .updated(events: events)
            |> \.widgetSetting .~ setting
    }
    
    private func todayEvents(
        _ todayRange: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        
        let events = try await self.eventsFetchusecase.fetchEvents(
            in: todayRange, timeZone
        )
        let filteredEventsWithTime = events.eventWithTimes.filter { event in
            guard let time = event.eventTime else { return false }
            return time.isOverlap(with: todayRange, in: timeZone)
        }
        return events
            |> \.eventWithTimes .~ filteredEventsWithTime
    }
}
