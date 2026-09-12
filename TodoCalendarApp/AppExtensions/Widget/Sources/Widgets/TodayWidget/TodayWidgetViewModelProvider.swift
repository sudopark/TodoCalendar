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
import CalendarPresentation
import WidgetScenes


// MARK: - TodayWidgetViewModel + CalendarEvents

extension TodayWidgetViewModel {

    func updated(events: CalendarEvents) -> TodayWidgetViewModel {
        let holiday = events.eventWithTimes.compactMap { $0 as? HolidayCalendarEvent }.first
        let todoCount = events.currentTodos.count + events.eventWithTimes.filter { $0 is TodoCalendarEvent }.count
        let scheduleCount = events.eventWithTimes.filter { $0 is ScheduleCalendarEvent }.count
        return self
            |> \.holidayName .~ holiday?.name
            |> \.todoEventCount .~ todoCount
            |> \.scheduleEventcount .~ scheduleCount
    }
}


final class TodayWidgetViewModelProvider {
    
    private let eventsFetchusecase: any CalendarEventFetchUsecase
    private let appSettingRepository: any AppSettingRepository
    private let calednarSettingRepository: any CalendarSettingRepository
    private let styleRepository: any WidgetStyleRepository
    
    init(
        eventsFetchusecase: any CalendarEventFetchUsecase,
        appSettingRepository: any AppSettingRepository,
        calednarSettingRepository: any CalendarSettingRepository,
        styleRepository: any WidgetStyleRepository
    ) {
        self.eventsFetchusecase = eventsFetchusecase
        self.appSettingRepository = appSettingRepository
        self.calednarSettingRepository = calednarSettingRepository
        self.styleRepository = styleRepository
    }
}

extension TodayWidgetViewModelProvider {
    
    
    func getTodayViewModel(for today: Date) async throws -> TodayWidgetViewModel {
        
        let setting = self.appSettingRepository.loadWidgetAppearanceSetting()
        let style = self.styleRepository.loadSetting(
            TodayStyleSetting.self, for: .init(variant: .todaySummarySmall, style: .default)
        ) ?? .init()
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let calednar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calednar.dayRange(today).unwrap()
        let events = try await self.todayEvents(todayRange, timeZone)
        return TodayWidgetViewModel(today, calednar)
            .updated(events: events)
            |> \.style .~ style
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
