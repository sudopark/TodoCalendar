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
import CalendarScenes


// MARK: - EventListWidgetViewModel

enum EventListWidgetSize {
    case small
    case medium
    case large
    
    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        default: self = .large
        }
    }
}

struct EventListWidgetViewModel {
    
    struct SectionModel {
        var sectionTitle: String?
        var events: [any EventCellViewModel]
        var shouldAccentTitle: Bool = false
        var isCurrentDay = false
        var isCurrentTodos = false
        
        init(
            title: String?,
            events: [any EventCellViewModel],
            shouldAccentTitle: Bool = false,
            isCurrentDay: Bool = false,
            isCurrentTodos: Bool = false
        ) {
            self.sectionTitle = title
            self.events = events
            self.shouldAccentTitle = shouldAccentTitle
            self.isCurrentDay = isCurrentDay
            self.isCurrentTodos = isCurrentTodos
        }
        
        fileprivate struct Builder {
            let calendar: Calendar
            let timeZone: TimeZone
            let is24Form: Bool
            let events: CalendarEvents
            
            func makeCurrentTodoListModel(
                _ events: [TodoCalendarEvent],
                _ range: Range<TimeInterval>
            ) -> SectionModel? {
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
            ) -> [SectionModel] {
                
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
                    let startDateModel = SectionModel(
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
    struct PageModel {
        var sections: [SectionModel]
        var needBottomSpace: Bool = false
        
        mutating func append(section: SectionModel) {
            self.sections.append(section)
        }
        
        mutating func append(event: any EventCellViewModel) {
            guard !self.sections.isEmpty else { return }
            self.sections[self.sections.count-1].events.append(event)
        }
    }
    
    var pages: [PageModel]
    let defaultTagColorSetting: DefaultEventTagColorSetting
    let customTagMap: [String: any EventTag]
    var googleCalendarColors: GoogleCalendar.Colors = .init(calendars: [:], events: [:])
    var googleCalendarTags: [String: GoogleCalendar.Tag] = [:]
    
    static func sample(size: EventListWidgetSize) -> EventListWidgetViewModel {
        
        let runningEvent = ScheduleEventCellViewModel("running", name: "🏃‍♂️ \("widget.events.sample::running".localized())")
            |> \.periodText .~ .singleText(.init(text: "8:00"))
        
        let lunchEvent = ScheduleEventCellViewModel("lunch", name: "🍔 \("widget.events.sample::luch".localized())")
            |> \.periodText .~ .singleText(.init(text: "1:00"))
        
        let callTodoEvent = TodoEventCellViewModel("call", name: "📞 \("Call Sara".localized())")
            |> \.periodText .~ .singleText(.init(text: "3:00"))
        
        let surfingEvent = ScheduleEventCellViewModel("surfing", name: "🏄‍♂️ \("widget.events.sample::surfing".localized())")
            |> \.periodText .~ .singleText(.init(text: "calendar::event_time::allday".localized()))
        
        let meeting = ScheduleEventCellViewModel("meeting", name: "widget.events.sample::meeting".localized())
        |> \.periodText .~ .singleText(.init(text: "10:00"))
        
        let golf = ScheduleEventCellViewModel("golf", name: "widget.weeks.sample::golf".localized())
        |> \.periodText .~ .singleText(.init(text: "calendar::event_time::allday".localized()))
        
        let recycle = TodoEventCellViewModel("recycle", name: "widget.events.sample::recycle".localized())
        |> \.periodText .~ .singleText(.init(text: "8:00"))
        
        let takeMedicine = TodoEventCellViewModel("take", name: "widget.events.sample::take_medicine".localized())
        |> \.periodText .~ .singleText(.init(text: "9:00"))
        
        let watering = TodoEventCellViewModel("water", name: "widget.events.sample::watering".localized())
        |> \.periodText .~ .singleText(.init(text: "12:00"))
        
        let holiday = HolidayEventCellViewModel(
            .init(.init(dateString: "2023-10-10", name: "widget.weeks.sample::holiday".localized()), in: .current)!
        )
        
        let defaultTagColorSetting = DefaultEventTagColorSetting(
            holiday: "#D6236A", default: "#088CDA"
        )
        
        switch size {
        case .small:
            let june3 = SectionModel(
                title: "widget.events.sample::june3".localized(),
                events: [ lunchEvent, callTodoEvent ],
                shouldAccentTitle: true
            )
            
            let july = SectionModel(title: "widget.events.sample::july16".localized(), events: [
                runningEvent, surfingEvent
            ])
            return .init(
                pages: [
                    .init(sections: [june3, july])
                ],
                defaultTagColorSetting: defaultTagColorSetting, customTagMap: [:]
            )
            
        case .medium:
            let june3 = SectionModel(
                title: "widget.events.sample::june3".localized(),
                events: [ lunchEvent, callTodoEvent ],
                shouldAccentTitle: true
            )
            
            let july = SectionModel(title: "widget.events.sample::july16".localized(), events: [
                runningEvent, surfingEvent
            ])
            let july21 = SectionModel(
                title: "widget.events.sample::july21".localized(), events: [
                    meeting
                ]
            )
            let oct = SectionModel(
                title: "widget.events.sample::oct10".localized(), events: [
                    holiday
                ]
            )
            return .init(
                pages: [
                    .init(sections: [june3, july]),
                    .init(sections: [july21, oct], needBottomSpace: true)
                ],
                defaultTagColorSetting: defaultTagColorSetting, customTagMap: [:]
            )
            
        case .large:
            let june3 = SectionModel(
                title: "widget.events.sample::june3".localized(),
                events: [ runningEvent, lunchEvent, callTodoEvent ],
                shouldAccentTitle: true
            )
            
            let july = SectionModel(title: "widget.events.sample::july16".localized(), events: [
                runningEvent, surfingEvent
            ])
            let july21 = SectionModel(
                title: "widget.events.sample::july21".localized(), events: [
                    meeting
                ]
            )
            let july27 = SectionModel(
                title: "widget.events.sample::july29".localized(), events: [
                    golf, recycle
                ]
            )
            let aug2 = SectionModel(
                title: "widget.events.sample::aug2".localized(), events: [
                    takeMedicine, meeting
                ]
            )
            let aug3 = SectionModel(
                title: "widget.events.sample::aug3".localized(), events: [
                    watering
                ]
            )
            let oct = SectionModel(
                title: "widget.events.sample::oct10".localized(), events: [
                    holiday
                ]
            )
            return .init(
                pages: [
                    .init(sections: [june3, july, july21, july27]),
                    .init(sections: [aug2, aug3, oct], needBottomSpace: true)
                ],
                defaultTagColorSetting: defaultTagColorSetting, customTagMap: [:]
            )
        }
    }
}


// MARK: - EventListWidgetViewModelProvider

final class EventListWidgetViewModelProvider {
    
    private let targetEventTagId: EventTagId
    private let eventsFetchUsecase: any CalendarEventFetchUsecase
    private let appSettingRepository: any AppSettingRepository
    private let calendarSettingRepository: any CalendarSettingRepository
    
    init(
        targetEventTagId: EventTagId,
        eventsFetchUsecase: any CalendarEventFetchUsecase,
        appSettingRepository: any AppSettingRepository,
        calendarSettingRepository: any CalendarSettingRepository
    ) {
        self.targetEventTagId = targetEventTagId
        self.eventsFetchUsecase = eventsFetchUsecase
        self.appSettingRepository = appSettingRepository
        self.calendarSettingRepository = calendarSettingRepository
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
            refDate, timeZone, setting.calendar.is24hourForm
        )
        let pages = dayEventLists.0.pagination(widgetSize)
        return EventListWidgetViewModel(
            pages: pages,
            defaultTagColorSetting: setting.defaultTagColor,
            customTagMap: dayEventLists.1.customTagMap
        )
        |> \.googleCalendarColors .~ (dayEventLists.1.googleCalendarColors ?? .init(calendars: [:], events: [:]))
        |> \.googleCalendarTags .~ dayEventLists.1.googleCalendarTags
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
        let target = self.targetEventTagId
        let total = try await self.eventsFetchUsecase.fetchEvents(in: range, timeZone)
        guard target != .default else { return total }
        return total
            |> \.currentTodos .~ total.currentTodos.filter { $0.eventTagId == target }
            |> \.eventWithTimes .~ total.eventWithTimes.filter { $0.eventTagId == target }
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

