//
//  TodayAndNextWidgetViewModel+Provider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 12/17/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation
import WidgetScenes


struct TodayAndNextWidgetViewModelBuilder {
 
    private let maxRowWeight: Float
    private let daysRangeSize: Int
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let setting: AppearanceSettings
    
    init(
        max: Float,
        daysRangeSize: Int,
        _ timeZone: TimeZone,
        _ setting: AppearanceSettings,
    ) {
        self.maxRowWeight = max
        self.daysRangeSize = daysRangeSize
        self.timeZone = timeZone
        self.calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        self.setting = setting
    }
    
    func build(
        _ now: Date,
        _ events: CalendarEvents
    ) -> TodayAndNextWidgetViewModel {
        // sort 필요
        let currentTodos = events.currentTodos
            .sortedByCreateTime()
            .compactMap { TodoEventCellViewModel(currentTodo: $0) }
            
        let eventsPerDay = self.gatherEvents(now, daysRangeSize, events: events)
        let todayEvents = eventsPerDay.first(where: { $0.offset == 0})
        let (leftPage, remain) = self.fillLeftPage(
            now,
            uncompletedTodos: self.todayUncompletedTodo(now, events: events),
            todayEvents: todayEvents?.events ?? [],
            currents: currentTodos
        )
        
        let notTodayEvents = eventsPerDay.filter { $0.offset != 0 }
        let rightPage = self.fillRightPage(remain, notTodayEvents)
        
        let todayNextEventTime = todayEvents.flatMap { self.selectRefreshTime($0.eventsThisDay, now: now) }
            
        return TodayAndNextWidgetViewModel(
            left: leftPage, right: rightPage,
            refreshAfter: todayNextEventTime,
            defaultTagColorSetting: setting.defaultTagColor,
            customTagMap: events.customTagMap
        )
    }
    
    private func selectRefreshTime(_ events: [any CalendarEvent], now: Date) -> TimeInterval? {
        let times = events.compactMap { $0.eventTime }.filter { !$0.isAllDay }
        guard let firstTimeIndex = times.firstIndex(where: { $0.lowerBoundWithFixed >= now.timeIntervalSince1970 })
        else { return nil }
        
        let firstEventTime = times[firstTimeIndex]
        let (firstStart, firstEnd) = (firstEventTime.lowerBoundWithFixed, firstEventTime.upperBoundWithFixed)
        guard let nextEventTime = times[safe: firstTimeIndex+1],
              firstEnd < nextEventTime.lowerBoundWithFixed
        else {
            return firstEnd
        }
        
        return max(firstStart, nextEventTime.lowerBoundWithFixed-10*60)
    }
    
    private struct EventsPerDay {
        let offset: Int
        let dateText: String
        let events: [any EventCellViewModel]
        fileprivate let eventsThisDay: [any CalendarEvent]
    }
    
    private func gatherEvents(
        _ now: Date, _ size: Int, events: CalendarEvents
    ) -> [EventsPerDay] {
        
        let is24Form = self.setting.calendar.is24hourForm
        func gather(_ offset: Int) -> EventsPerDay? {
            guard let day = calendar.addDays(offset, from: now),
                  let daysrange = calendar.dayRange(day)
            else { return nil }
            
            let eventsThisDay = events.eventWithTimes
                .filter { ev in
                    ev.eventTime?.isOverlap(with: daysrange, in: timeZone) ?? false
                }
                .filter {
                    // 오늘인 경우, 종일 이벤트가 아니라면 남은 이벤트만 필터링
                    if offset == 0, let time = $0.eventTime, !time.isAllDay, time.lowerBoundWithFixed < now.timeIntervalSince1970 {
                        return false
                    } else {
                        return true
                    }
                }
            
            let dateText = switch offset {
                case 0: ""
                case 1: "tomorrow".localized()
                default: day.text("date_form.MMM_dd_E".localized(), timeZone: timeZone)
            }
            
            let cvms = eventsThisDay.compactMap { event -> (any EventCellViewModel)? in
                switch event {
                case let todo as TodoCalendarEvent:
                    return TodoEventCellViewModel(
                        todo, in: daysrange, timeZone, is24Form
                    )
                    
                case let schedule as ScheduleCalendarEvent:
                    return ScheduleEventCellViewModel(
                        schedule, in: daysrange, timeZone: timeZone, is24Form
                    )
                    
                case let holiday as HolidayCalendarEvent:
                    return HolidayEventCellViewModel(holiday)
                    
                case let google as GoogleCalendarEvent:
                    return GoogleCalendarEventCellViewModel(
                        google, in: daysrange, timeZone, is24Form
                    )

                case let apple as AppleCalendarEvent:
                    return AppleCalendarEventCellViewModel(
                        apple, in: daysrange, timeZone, is24Form
                    )

                default: return nil
                }
            }

            return .init(offset: offset, dateText: dateText, events: cvms, eventsThisDay: eventsThisDay)
        }
        
        return (0..<size+1).compactMap(gather(_:))
    }
    
    private func todayUncompletedTodo(
        _ now: Date, events: CalendarEvents
    ) -> [TodoCalendarEvent] {
        guard let todayRange = calendar.dayRange(now) else { return [] }
        let todoEvents = events.eventWithTimes
            .filter { ev in
                ev.eventTime?.isOverlap(with: todayRange, in: timeZone) ?? false
            }
            .compactMap { $0 as? TodoCalendarEvent }
        let uncompleteds = todoEvents.filter { todo in
            if let time = todo.eventTime, !time.isAllDay {
                return time.lowerBoundWithFixed < now.timeIntervalSince1970
            } else {
                return false
            }
        }
        return uncompleteds
    }
}

// MARK: - fill left page

extension TodayAndNextWidgetViewModelBuilder {
    
    private func fillLeftPage(
        _ now: Date,
        uncompletedTodos: [TodoCalendarEvent],
        todayEvents: [any EventCellViewModel],
        currents: [TodoEventCellViewModel]
    ) -> (
        left: TodayAndNextWidgetViewModel.PageModel,
        remain: [TodayAndNextWidgetViewModel.EventModel]
    ) {

        var page = TodayAndNextWidgetViewModel.PageModel()
        
        // 오늘 모델 추가
        let todayModel = self.makeTodayModel(now, todayEvents)
        page.rows = [todayModel]
        
        // 완료되지 않은 할일
        if let uncompletedModel = TodayAndNextWidgetViewModel.UncompletedTodayTodoSummaryModel(uncompletedTodos) {
            page.rows.append(uncompletedModel)
        }
        
        
        // 지금 할일 or 오늘 하루종일에 해당하는 일정 주가
        var remainSpace = page.remainWeight(maxRowWeight)
        // TODO: 공휴일도 표시하도록
        let notHolidayTodayEvents = todayEvents.filter { !($0 is HolidayEventCellViewModel) }
        let todayAlldayEvents = notHolidayTodayEvents.filter { $0.isAlldayEvent  }
        let currentOrAllDayEvents = self.makeCurrentOrTodayAllDayRows(currents, todayAlldayEvents, remainSpace)
        page.rows.append(contentsOf: currentOrAllDayEvents)
        
        // 이후 잔여 공간 오늘 이벤트 채울수있는 만큼 채움
        remainSpace = page.remainWeight(maxRowWeight)
        let todayNotAllDayEvents = notHolidayTodayEvents
            .filter { !$0.isAlldayEvent }
            .map { TodayAndNextWidgetViewModel.EventModel(cvm: $0) }
        let (prefix, remain) = todayNotAllDayEvents.slice(by: remainSpace)
        page.rows.append(contentsOf: prefix)
        
        return (page, remain)
    }
    
    private func makeTodayModel(
        _ today: Date, _ todayEvents: [any EventCellViewModel]?
    ) -> TodayAndNextWidgetViewModel.TodayModel {
        var todayModel = TodayAndNextWidgetViewModel.TodayModel(
            weekOfDay: today.text("date_form.EEEE".localized(), timeZone: timeZone),
            day: calendar.component(.day, from: today)
        )
        if timeZone != TimeZone.current {
            todayModel.timeZonetext = timeZone.localizedName(for: .shortStandard, locale: .current)
        }
        return todayModel
    }
    
    private func makeCurrentOrTodayAllDayRows(
        _ currents: [TodoEventCellViewModel],
        _ allDayEvents: [any EventCellViewModel],
        _ remain: Float
    ) -> [any TodayAndNextWidgetViewModelRow] {
        
        let currentModels = currents.map {
            TodayAndNextWidgetViewModel.EventModel(cvm: $0)
        }
        let allDays = allDayEvents.map {
            TodayAndNextWidgetViewModel.EventModel(cvm: $0)
        }
        
        let totalModels = currentModels + allDays
        return totalModels.summarizeIfNeed(withIn: remain)
    }
}

// MARK: - fill right page

extension TodayAndNextWidgetViewModelBuilder {
    
    private func fillRightPage(
        _ todayRemains: [TodayAndNextWidgetViewModel.EventModel],
        _ notTodayEvents: [EventsPerDay]
    ) -> TodayAndNextWidgetViewModel.PageModel {
        
        var page = TodayAndNextWidgetViewModel.PageModel(); var notTodayEvents: [EventsPerDay] = notTodayEvents
        
        var remain = self.maxRowWeight
        // 잔여 공간 내에서 오늘 이벤트 다 채움, 공간 모자르면 축약형으로 채움
        let todayModels = todayRemains.summarizeIfNeed(withIn: remain)
        page.rows.append(contentsOf: todayModels)
        
        remain = page.remainWeight(maxRowWeight)
        
        while !notTodayEvents.isEmpty {
            let next = notTodayEvents.removeFirst()
            if next.events.isEmpty {
                continue
            }
            let dateModel = TodayAndNextWidgetViewModel.DateModel(dateText: next.dateText)
            let events = next.events.map { TodayAndNextWidgetViewModel.EventModel(cvm: $0) }
            
            // 내일의 경우 축약형 없이 더할수있는 만큼 추가
            if next.offset == 1,
               case let (prefix, _) = events.slice(by: remain-dateModel.rowWeight),
               !prefix.isEmpty {
                
                page.rows.append(contentsOf: [dateModel] + prefix)
                
                // 내일 외 날짜의 경우 축약형 제공
            } else if next.offset != 1,
                      case let summarized = events.summarizeIfNeed(withIn: remain-dateModel.rowWeight),
                      !summarized.isEmpty
                {
                
                page.rows.append(contentsOf: [dateModel] + summarized)
            } else {
                break
            }
            remain = page.remainWeight(maxRowWeight)
        }
        
        return page
    }
}


// MARK: - TodayAndNextWidgetViewModelProvider

final class TodayAndNextWidgetViewModelProvider {
    
    private enum Constant {
        static let maxRowSpaceWeight: Float = 4
        static let daysRangeCount: Int = 10
    }
    
    private let targetEventTagIds: [EventTagId]?
    private let excludeAllDayEvents: Bool
    private let eventsFetchUsecase: any CalendarEventFetchUsecase
    private let calendarSettingRepository: any CalendarSettingRepository
    private let appSettingRepository: any AppSettingRepository
    private let localeProvider: any LocaleProvider
    
    init(
        targetEventTagIds: [EventTagId]?,
        excludeAllDayEvents: Bool,
        eventsFetchUsecase: any CalendarEventFetchUsecase,
        calendarSettingRepository: any CalendarSettingRepository,
        appSettingRepository: any AppSettingRepository,
        localeProvider: any LocaleProvider
    ) {
        self.targetEventTagIds = targetEventTagIds
        self.excludeAllDayEvents = excludeAllDayEvents
        self.eventsFetchUsecase = eventsFetchUsecase
        self.calendarSettingRepository = calendarSettingRepository
        self.appSettingRepository = appSettingRepository
        self.localeProvider = localeProvider
    }
}

extension TodayAndNextWidgetViewModelProvider {
    
    func getViewModel(
        for refDate: Date
    ) async throws -> TodayAndNextWidgetViewModel {
        
        let timeZone = self.calendarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        let events = try await self.loadEvnets(from: refDate, timeZone)
        let builder = TodayAndNextWidgetViewModelBuilder(
            max: Constant.maxRowSpaceWeight, daysRangeSize: Constant.daysRangeCount,
            timeZone, setting
        )
        let model = builder.build(refDate, events)
        
        return model
            |> \.googleCalendarColors .~ (events.googleCalendarColors ?? .init(ownerId: "", calendars: [:], events: [:]))
            |> \.googleCalendarTags .~ events.googleCalendarTags
            |> \.appleCalendarTags .~ events.appleCalendarTags
            |> \.widgetSetting .~ setting.widget
    }
    
    private func loadEvnets(
        from date: Date, _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let endDate = calendar.addDays(10, from: date).flatMap(calendar.endOfDay(for:))
        else {
            throw RuntimeError("failed")
        }
        
        let range = calendar.startOfDay(for: date).timeIntervalSince1970..<endDate.timeIntervalSince1970
        let total = try await self.eventsFetchUsecase.fetchEvents(in: range, timeZone)
        
        var currents = total.currentTodos; var eventWithTimes = total.eventWithTimes
        if let selected = self.targetEventTagIds.map({ Set($0) }) {
            currents = currents.filter { selected.contains($0.eventTagId )}
            eventWithTimes = eventWithTimes.filter { selected.contains($0.eventTagId) }
        }
        if self.excludeAllDayEvents {
            eventWithTimes = eventWithTimes.filter { !($0.eventTime?.isAllDay ?? false) }
        }
        
        return total
            |> \.currentTodos .~ currents
            |> \.eventWithTimes .~ eventWithTimes
    }
}


private extension Array where Element == TodayAndNextWidgetViewModel.EventModel {
    
    func slice(by availSpace: Float) -> (Array, Array) {
        let weightSums = self.reduce([Float]()) { acc, row in
            let new = (acc.last ?? 0) + row.rowWeight
            return acc + [new]
        }
        let divIndex = weightSums.firstIndex(where: { $0 > availSpace }) ?? self.count
        let prefix = self[0..<divIndex]
        let suffix = self[divIndex...]
        
        return (Array(prefix), Array(suffix))
    }
    
    /**
     prefix, suffix
     0, 0 -> [],
     0, n -> [],
     1, n -> S(1+n)
     n, 0 -> n
     n, 1 -> n-1 + S(1+1)
     n, m -> n-1 + S(1+m)
     */
    func summarizeIfNeed(withIn size: Float) -> [any TodayAndNextWidgetViewModelRow] {
        
        var (prefix, suffix) = self.slice(by: size)
        guard !prefix.isEmpty, !suffix.isEmpty
        else {
            return prefix
        }
        
        let prefixLast = prefix.removeLast()
        let summarizePool = [prefixLast] + suffix
        
        let summarize = TodayAndNextWidgetViewModel.MultipleEventsSummaryModel(summarizePool)
        return prefix + [summarize]
    }
}
