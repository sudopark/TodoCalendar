//
//  WidgetCalendarEventFetchUsecase.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - CalendarEventFetchUsecase + CalendarEvents

struct CalendarEvents {
    var currentTodos: [TodoCalendarEvent]
    var eventWithTimes: [any CalendarEvent]
    var customTagMap: [String: EventTag]
    
    func findFirstFutureEvent(from time: TimeInterval) -> (any CalendarEvent)? {
        return self.eventWithTimes.first { event in
            guard !(event is HolidayCalendarEvent), let eventTime = event.eventTime
            else { return false }
            return eventTime.lowerBoundWithFixed > time
        }
    }
}

struct ForemostEvent {
    let foremostEvent: (any ForemostMarkableEvent)?
    let tag: EventTag?
}

struct TodayNextEvent {
    let nextEvent: any CalendarEvent
    let tag: EventTag?
    var andThenNextEventStartDate: Date?
}

protocol CalendarEventFetchUsecase {
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents
    
    func fetchForemostEvent() async throws -> ForemostEvent
    
    func fetchNextEvent(
        _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvent?
}


// MARK: - CalendarEventFetchUsecaseImple

actor CalendarEventsFetchCacheStore {
    var currentTodos: [TodoCalendarEvent]?
    var allCustomTagsMap: [String: EventTag]?
    
    func updateCurrentTodos(_ todos: [TodoCalendarEvent]) {
        self.currentTodos = todos
    }
    func updateAllCustomTagsMap(_ newValue: [String: EventTag]) {
        self.allCustomTagsMap = newValue
    }

    func reset() {
        self.currentTodos = nil
        self.allCustomTagsMap = nil
    }
    
    func resetCurrentTodo() {
        self.currentTodos = nil
    }
}


final class CalendarEventFetchUsecaseImple: CalendarEventFetchUsecase {
    
    private let todoRepository: any TodoEventRepository
    private let scheduleRepository: any ScheduleEventRepository
    private let foremostEventRepository: any ForemostEventRepository
    private let holidayFetchUsecase: any HolidaysFetchUsecase
    private let eventTagRepository: any EventTagRepository
    private let cached: CalendarEventsFetchCacheStore
    
    init(
        todoRepository: any TodoEventRepository,
        scheduleRepository: any ScheduleEventRepository,
        foremostEventRepository: any ForemostEventRepository,
        holidayFetchUsecase: any HolidaysFetchUsecase,
        eventTagRepository: any EventTagRepository,
        cached: CalendarEventsFetchCacheStore
    ) {
        self.todoRepository = todoRepository
        self.scheduleRepository = scheduleRepository
        self.foremostEventRepository = foremostEventRepository
        self.holidayFetchUsecase = holidayFetchUsecase
        self.eventTagRepository = eventTagRepository
        self.cached = cached
    }
}

extension CalendarEventFetchUsecaseImple {
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        
        let customTagMap = try await self.allCustomEventTagMap()
        let currentTodos = try await self.currentTodoEvents(timeZone)
        let todosInRange = try await self.todoEvents(in: range, timeZone)
        let schedulesInRange = try await self.scheduleEvents(in: range, timeZone)
        let holidaysInRage = try await self.holidays(in: range, timeZone)
        
        let eventsWithTime: [any CalendarEvent] = todosInRange + schedulesInRange + holidaysInRage
        
        let events = CalendarEvents(
            currentTodos: currentTodos,
            eventWithTimes: eventsWithTime.sorted(),
            customTagMap: customTagMap
        )
        return events
    }

    private func allCustomEventTagMap() async throws -> [String: EventTag] {
        if let cached = await self.cached.allCustomTagsMap {
            return cached
        }
        let tags = try await self.eventTagRepository.loadAllTags()
            .values.first(where: { _ in true }) ?? []
        let tagMap = tags.asDictionary { $0.uuid }
        await self.cached.updateAllCustomTagsMap(tagMap)
        return tagMap
    }
    
    private func currentTodoEvents(
        _ timeZone: TimeZone
    ) async throws -> [TodoCalendarEvent] {
        if let cached = await self.cached.currentTodos {
            return cached
        }
        let todos = (try await self.todoRepository.loadCurrentTodoEvents()
            .values.first(where: { _ in true }) ?? [])
            .map { TodoCalendarEvent($0, in: timeZone) }
        await self.cached.updateCurrentTodos(todos)
        return todos
    }
    
    private func todoEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [TodoCalendarEvent] {
        let todos = try await self.todoRepository.loadTodoEvents(in: range)
            .values.first(where: { _ in true }) ?? []
        return todos.map { TodoCalendarEvent($0, in: timeZone) }
    }
    
    private func scheduleEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [ScheduleCalendarEvent] {
        let events = try await scheduleRepository.loadScheduleEvents(in: range)
            .values.first(where: { _ in true }) ?? []
        let eventContainer = MemorizedScheduleEventsContainer()
            .refresh(events, in: range)
        let eventWithRepeatTimeCalculated = eventContainer.allCachedEvents()
        return eventWithRepeatTimeCalculated.flatMap {
            ScheduleCalendarEvent.events(from: $0, in: timeZone)
        }
    }
    
    private func holidays(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [HolidayCalendarEvent] {
        let holidays = try await self.holidayFetchUsecase.holidaysGivenYears(
            range, timeZone: timeZone
        )
        let events = holidays.compactMap { HolidayCalendarEvent($0, in: timeZone) }
        return events.filter { $0.eventTime?.isRoughlyOverlap(with: range) ?? false }
    }
}

extension CalendarEventFetchUsecaseImple {
    
    func fetchForemostEvent() async throws -> ForemostEvent {
        let tags = try await self.allCustomEventTagMap()
        let event = try await self.loadForemostEvent()
        return ForemostEvent(
            foremostEvent: event,
            tag: event.flatMap { $0.eventTagId?.customTagId }.flatMap { tags[$0] }
        )
    }
    
    private func loadForemostEvent() async throws -> (any ForemostMarkableEvent)? {
        return try await self.foremostEventRepository.foremostEvent().values.first(where: { _ in true }) ?? nil
    }
}

extension CalendarEventFetchUsecaseImple {
    
    func fetchNextEvent(
        _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvent? {
        
        let events = try await self.fetchEvents(in: todayRange, timeZone)
        
        guard let firstFutureEvent = events.findFirstFutureEvent(from: refTime.timeIntervalSince1970)
        else {
            return nil
        }
        let secondFutureEvent = firstFutureEvent.eventTime.flatMap {
            return events.findFirstFutureEvent(from: $0.lowerBoundWithFixed)
        }
        let tag = firstFutureEvent.eventTagId.customTagId.flatMap {
            return events.customTagMap[$0]
        }
        
        return TodayNextEvent(nextEvent: firstFutureEvent, tag: tag)
            |> \.andThenNextEventStartDate .~ secondFutureEvent?.eventTime.map {
                Date(timeIntervalSince1970: $0.lowerBoundWithFixed)
            }
    }
}

private extension Array where Element == CalendarEvent {
    
    func sorted() -> Array {
        return self.sorted(by: { lhs, rhs in
            switch (lhs.eventTime?.lowerBoundWithFixed, rhs.eventTime?.lowerBoundWithFixed) {
            case (.none, .none): return true
            case (.none, .some): return false
            case (.some, .none): return true
            case (.some(let lt), .some(let rt)): return lt < rt
            }
        })
    }
}
