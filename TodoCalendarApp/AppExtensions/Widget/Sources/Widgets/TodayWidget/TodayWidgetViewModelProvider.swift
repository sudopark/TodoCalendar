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
    
    
    /// 인스턴스가 스타일을 안 고르는 합성 위젯도 같은 경로를 쓴다 — 그쪽은 변형 기본 스타일이다.
    func getTodayViewModel(
        for today: Date, style: WidgetStyleId.Style = .default
    ) async throws -> TodayWidgetViewModel {
        
        let setting = self.appSettingRepository.loadWidgetAppearanceSetting()
        let styleSetting = self.styleSetting(style)
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let calednar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calednar.dayRange(today).unwrap()
        let events = try await self.todayEvents(todayRange, timeZone)
        return TodayWidgetViewModel(today, calednar)
            .updated(events: events)
            |> \.style .~ styleSetting
            |> \.widgetSetting .~ setting
    }
    
    /// 인스턴스가 고른 스타일 → 변형 기본 스타일 → 코드 기본값 순으로 내려간다.
    private func styleSetting(_ style: WidgetStyleId.Style) -> TodayStyleSetting {
        return self.savedStyleSetting(style) ?? self.savedStyleSetting(.default) ?? .initial
    }
    
    private func savedStyleSetting(_ style: WidgetStyleId.Style) -> TodayStyleSetting? {
        return self.styleRepository.loadSetting(
            for: .init(variant: .todaySummarySmall, style: style)
        ) as? TodayStyleSetting
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
