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
        // 타임라인 생성마다 도는 자리라 저장소는 두 번만 읽고 두 해석이 그 값을 나눠 쓴다.
        let instance = self.savedStyle(style)
        let variantDefault = style == .default ? instance : self.savedStyle(.default)
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let calednar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calednar.dayRange(today).unwrap()
        let events = try await self.todayEvents(todayRange, timeZone)
        return TodayWidgetViewModel(today, calednar)
            .updated(events: events)
            |> \.style .~ self.styleSetting(instance: instance, variantDefault: variantDefault)
            |> \.widgetSetting .~ (
                setting |> \.background .~ self.background(
                    instance: instance, variantDefault: variantDefault, global: setting
                )
            )
    }
    
    /// 인스턴스가 고른 스타일 → 변형 기본 스타일 → 코드 기본값 순으로 내려간다.
    private func styleSetting(
        instance: WidgetStyle?, variantDefault: WidgetStyle?
    ) -> TodayStyleSetting {
        return instance?.setting as? TodayStyleSetting
            ?? variantDefault?.setting as? TodayStyleSetting
            ?? .initial
    }
    
    /// 폴백은 스타일 단위다 — 고른 스타일이 색을 안 걸었으면 그 스타일이 "전역 따름"인 것이지
    /// 기본 스타일의 색을 빌려오는 게 아니다. 변형 기본으로 내려가는 건 고른 스타일이 지워졌을 때뿐이다.
    private func background(
        instance: WidgetStyle?,
        variantDefault: WidgetStyle?,
        global: WidgetAppearanceSettings
    ) -> WidgetAppearanceSettings.Background {
        return (instance ?? variantDefault)?.background ?? global.background
    }
    
    private func savedStyle(_ style: WidgetStyleId.Style) -> WidgetStyle? {
        return self.styleRepository.loadStyle(
            for: .init(variant: .todaySummarySmall, style: style)
        )
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
