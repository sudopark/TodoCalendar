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
import CalendarPresentation
import WidgetScenes


// MARK: - MonthWidgetViewModelProvider

final class MonthWidgetViewModelProvider {
    
    private let calendarUsecase: any CalendarUsecase
    private let settingRepository: any CalendarSettingRepository
    private let appSettingRepository: any AppSettingRepository
    private let holidayFetchUsecase: any HolidaysFetchUsecase
    private let eventFetchUsecase: any CalendarEventFetchUsecase
    private let styleRepository: any WidgetStyleRepository
    
    init(
        calendarUsecase: any CalendarUsecase,
        settingRepository: any CalendarSettingRepository,
        appSettingRepository: any AppSettingRepository,
        holidayFetchUsecase: any HolidaysFetchUsecase,
        eventFetchUsecase: any CalendarEventFetchUsecase,
        styleRepository: any WidgetStyleRepository
    ) {
        self.calendarUsecase = calendarUsecase
        self.settingRepository = settingRepository
        self.appSettingRepository = appSettingRepository
        self.holidayFetchUsecase = holidayFetchUsecase
        self.eventFetchUsecase = eventFetchUsecase
        self.styleRepository = styleRepository
    }
}

extension MonthWidgetViewModelProvider {
    
    /// 인스턴스가 스타일을 안 고르는 합성 위젯도 같은 경로를 쓴다 — 그쪽은 변형 기본 스타일이다.
    func getMonthViewModel(
        _ now: Date, style: WidgetStyleId.Style = .default
    ) async throws -> MonthWidgetViewModel {
        let timeZone = self.settingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadWidgetAppearanceSetting()
        let resolved = self.styleRepository.resolveStyle(of: .monthSmall, style: style)
        var model = try await self.currentMonthModel(now, timeZone)
        if let ranges = model.eventRange {
            model.hasEventDaysIdentifiers = await self.loadEventExistsDayIdentifiers(
                ranges, timeZone
            )
        }
        return model
            |> \.look .~ .init(globalSetting: setting, appliedStyle: resolved)
    }
    
    private func currentMonthModel(_ now: Date, _ timeZone: TimeZone) async throws -> MonthWidgetViewModel {
        let firstWeekDay = self.settingRepository.firstWeekDay() ?? .sunday
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let today = CalendarComponent.Day(now, calendar: calendar)
        let (year, month) = (
            calendar.component(.year, from: now), 
            calendar.component(.month, from: now)
        )
        let holidays = await self.loadHolidays(now, timeZone)
        let components = try self.calendarUsecase
            .getComponents(year, month, firstWeekDay)
            .update(holidays: holidays)
        
        return .init(now, firstWeekDay, timeZone, components, today.identifier)
    }
    
    private func loadHolidays(_ refTime: Date, _ timeZone: TimeZone) async -> [Holiday] {
        let range = refTime.timeIntervalSince1970..<refTime.timeIntervalSince1970+1
        return (try? await self.holidayFetchUsecase.holidaysGivenYears(range, timeZone: timeZone)) ?? []
    }
    
    private func loadEventExistsDayIdentifiers(
        _ range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async -> Set<String> {
        guard let events = try? await self.eventFetchUsecase.fetchEvents(in: range, timeZone, withoutOffTagIds: true)
        else { return [] }
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let eventTimeIdentifiers = events.eventWithTimes
            .filter { ($0 is HolidayCalendarEvent) == false }
            .compactMap { $0.eventTime }
            .map { EventTimeOnCalendar($0, timeZone: timeZone) }
            .compactMap { $0.clamped(to: range) }
            .flatMap { calendar.daysIdentifiers($0) }
        return Set(eventTimeIdentifiers)
    }
}
