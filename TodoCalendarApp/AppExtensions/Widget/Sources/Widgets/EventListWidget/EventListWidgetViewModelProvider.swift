//
//  EventListWidgetViewModelProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation
import WidgetScenes


// MARK: - SectionModel.Builder

extension EventListWidgetViewModel.SectionModel {

    struct Builder {
        let calendar: Calendar
        let timeZone: TimeZone
        let is24Form: Bool
        let events: CalendarEvents
        
        func makeCurrentTodoListModel(
            _ events: [TodoCalendarEvent],
            _ range: Range<TimeInterval>
        ) -> EventListWidgetViewModel.SectionModel? {
            let models: [any EventCellViewModel] = events
                .sortedByCreateTime()
                .compactMap {
                    TodoEventCellViewModel($0, in: range, self.timeZone, self.is24Form)
                }
            guard !models.isEmpty else { return nil }
            return .init(
                title: "widget.events.currentTodos".localized(),
                events: models,
                shouldAccentTitle: true,
                isCurrentTodos: true
            )
        }
        
        func make(
            events: [any CalendarEvent],
            in range: Range<TimeInterval>,
            size: Int
        ) -> [EventListWidgetViewModel.SectionModel] {
            
            let start = Date(timeIntervalSince1970: range.lowerBound)
            
            let gatherEventsPerDay: (Int) -> EventListWidgetViewModel.SectionModel? = { offset in
                guard let dayRange = calendar.addDays(offset, from: start).flatMap(calendar.dayRange(_:))
                else { return nil }
                
                let eventsThisDay = events
                    .filter { $0.eventTime?.isOverlap(with: dayRange, in: self.timeZone) ?? false }
                    .sortedByEventTime()
                let models = eventsThisDay.compactMap { event -> (any EventCellViewModel)? in
                    switch event {
                    case let todo as TodoCalendarEvent:
                        return TodoEventCellViewModel(todo, in: dayRange, timeZone, is24Form)
                    case let schedule as ScheduleCalendarEvent:
                        return ScheduleEventCellViewModel(schedule, in: dayRange, timeZone: timeZone, is24Form)
                    case let holiday as HolidayCalendarEvent:
                        return HolidayEventCellViewModel(holiday)
                    case let google as GoogleCalendarEvent:
                        return GoogleCalendarEventCellViewModel(google, in: dayRange, timeZone, is24Form)
                    case let apple as AppleCalendarEvent:
                        return AppleCalendarEventCellViewModel(apple, in: dayRange, timeZone, is24Form)
                    default: return nil
                    }
                }
                
                guard offset == 0 || !models.isEmpty else { return nil }

                let dateText = Date(timeIntervalSince1970: dayRange.lowerBound)
                    .text("date_form.EEE_MMM_d".localized(), timeZone: timeZone)
                return .init(
                    title: dateText,
                    events: models,
                    shouldAccentTitle: offset == 0,
                    isCurrentDay: offset == 0
                )
            }
            
            let models = (0..<size+1).compactMap(gatherEventsPerDay)
            if models.isEmpty {
                let dateText = Date(timeIntervalSince1970: start.timeIntervalSince1970)
                    .text("date_form.EEE_MMM_d".localized(), timeZone: timeZone)
                let startDateModel = EventListWidgetViewModel.SectionModel(
                    title: dateText, events: [],
                    shouldAccentTitle: true,
                    isCurrentDay: true
                )
                return [startDateModel]
            }
            return models
        }
    }
}


extension EventListWidgetSize {

    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        default: self = .large
        }
    }
}


// MARK: - EventListWidgetViewModelProvider

final class EventListWidgetViewModelProvider {
    
    private let targetEventTagIds: [EventTagId]?
    private let eventsFetchUsecase: any CalendarEventFetchUsecase
    private let appSettingRepository: any AppSettingRepository
    private let calendarSettingRepository: any CalendarSettingRepository
    private let localeProvider: any LocaleProvider
    
    init(
        targetEventTagIds: [EventTagId]?,
        eventsFetchUsecase: any CalendarEventFetchUsecase,
        appSettingRepository: any AppSettingRepository,
        calendarSettingRepository: any CalendarSettingRepository,
        localeProvider: any LocaleProvider
    ) {
        self.targetEventTagIds = targetEventTagIds
        self.eventsFetchUsecase = eventsFetchUsecase
        self.appSettingRepository = appSettingRepository
        self.calendarSettingRepository = calendarSettingRepository
        self.localeProvider = localeProvider
    }
}

extension EventListWidgetViewModelProvider {
    
    func getEventListViewModel(
        for refDate: Date,
        widgetSize: EventListWidgetSize
    ) async throws -> EventListWidgetViewModel {
        
        let timeZone = self.calendarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        
        let dayEventLists = try await self.loadDayEventListModel(
            refDate, timeZone, localeProvider.is24HourFormat()
        )
        let pages = dayEventLists.0.pagination(widgetSize)
        return EventListWidgetViewModel(
            pages: pages,
            defaultTagColorSetting: setting.defaultTagColor,
            customTagMap: dayEventLists.1.customTagMap
        )
        |> \.googleCalendarColors .~ (dayEventLists.1.googleCalendarColors ?? .init(ownerId: "", calendars: [:], events: [:]))
        |> \.googleCalendarTags .~ dayEventLists.1.googleCalendarTags
        |> \.appleCalendarTags .~ dayEventLists.1.appleCalendarTags
        |> \.widgetSetting .~ setting.widget
    }
   
    private func loadDayEventListModel(
        _ start: Date,
        _ timeZone: TimeZone,
        _ is24Form: Bool
    ) async throws -> ([EventListWidgetViewModel.SectionModel], CalendarEvents) {
        
        let rangeSize: Int = 90
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        
        guard let endDate = calendar.addDays(rangeSize, from: start).flatMap(calendar.endOfDay(for:))
        else { return ([], .init()) }
        
        let range = calendar.startOfDay(for: start).timeIntervalSince1970..<endDate.timeIntervalSince1970
        
        let totalEvents = try await self.loadEventList(in: range, timeZone)
        
        let builder = EventListWidgetViewModel.SectionModel.Builder(
            calendar: calendar, timeZone: timeZone, is24Form: is24Form, events: totalEvents
        )
        
        var modelLists = builder.make(events: totalEvents.eventWithTimes, in: range, size: rangeSize)
        
        if let currentModel = builder.makeCurrentTodoListModel(totalEvents.currentTodos, range) {
            modelLists.insert(currentModel, at: 0)
        }
        return (modelLists, totalEvents)
    }
    
    private func loadEventList(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        let total = try await self.eventsFetchUsecase.fetchEvents(in: range, timeZone)
        guard let selecteds = self.targetEventTagIds.map({ Set($0) })
        else {
            return total
        }
        return total
            |> \.currentTodos .~ total.currentTodos.filter { selecteds.contains($0.eventTagId) }
            |> \.eventWithTimes .~ total.eventWithTimes.filter { selecteds.contains($0.eventTagId) }
    }
}

private extension Array where Element == any CalendarEvent {
    
}

private extension Array where Element == EventListWidgetViewModel.SectionModel {
    
    struct ItemMaxCountPerPage {
        let singleSection: Int
        let mutipleSection: Int
    }
    
    func pagination(_ size: EventListWidgetSize) -> [EventListWidgetViewModel.PageModel] {
        switch size {
        case .small:
            return self.split(
                .init(singleSection: 5, mutipleSection: 5),
                maxPageCount: 1
            )
        case .medium:
            return self.split(
                .init(singleSection: 5, mutipleSection: 5),
                maxPageCount: 2
            )
        case .large:
            return self.split(
                .init(singleSection: 12, mutipleSection: 12),
                maxPageCount: 2
            )
        }
    }
    
    private enum Row {
        case section(EventListWidgetViewModel.SectionModel)
        case event(any EventCellViewModel)
    }
    
    func split(
        _ counts: ItemMaxCountPerPage, maxPageCount: Int
    ) -> [EventListWidgetViewModel.PageModel] {
           
        let totalRows = self.reduce(into: [Row]()) { acc, section in
            acc.append(.section(section))
            acc.append(contentsOf: section.events.map { .event($0)})
        }
        let isCurrentDayEventEmpty = self.first(where: { $0.isCurrentDay })?.events.isEmpty ?? false
        
        var pages: [EventListWidgetViewModel.PageModel] = []; var pageIndex = 0; var index = 0;
        
        while pageIndex < maxPageCount {
            
            var currentPage = EventListWidgetViewModel.PageModel(sections: [])
            var rowCount = 0
            
            func isRemainRow(afterAppendRow: Int = 0) -> Bool {
                let thisPageHasMultipleSection = currentPage.sections.count > 1
                if thisPageHasMultipleSection {
                    return rowCount + afterAppendRow <= counts.mutipleSection
                } else {
                    return rowCount + afterAppendRow <= counts.singleSection
                }
            }
            
            func appendRowsIfRemain() -> Bool {
                switch totalRows[index] {
                case .section(var newSection):
                    newSection = newSection |> \.events .~ []
                    guard isRemainRow(afterAppendRow: 2) else { return false }
                    
                    currentPage.append(section: newSection)
                    rowCount += 1
                    
                case .event(let event):
                    guard isRemainRow(afterAppendRow: 1) else { return false }
                    if currentPage.sections.last == nil {
                        currentPage.append(section: .init(title: nil, events: []))
                    }
                    currentPage.append(event: event)
                    rowCount += 1
                }
                return true
            }
            
            while index < totalRows.count {
                if appendRowsIfRemain() {
                    index += 1
                } else {
                    break
                }
            }
            
            if pageIndex == maxPageCount-1 {
                currentPage.needBottomSpace = isRemainRow(afterAppendRow: 1)
            }
            if !currentPage.sections.isEmpty {
                pages.append(currentPage)
            }
            pageIndex += 1
        }
        
        return pages
    }
}

private extension EventListWidgetViewModel.SectionModel {
    
    func prefixIfNeed(_ remainCount: Int) -> EventListWidgetViewModel.SectionModel {
        if self.events.count > remainCount {
            return self |> \.events %~ { Array($0.prefix(remainCount)) }
        } else {
            return self
        }
    }
}

