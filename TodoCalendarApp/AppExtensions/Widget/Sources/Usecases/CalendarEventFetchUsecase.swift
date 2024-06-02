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


struct CalendarEvents {
    let currentTodos: [TodoCalendarEvent]
    let eventWithTimes: [any CalendarEvent]
    let customTagMap: [String: EventTag]
}

protocol CalendarEventFetchUsecase {
    
    func reset() async
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents
}


final class CalendarEventFetchUsecaseImple: CalendarEventFetchUsecase {
    
    private let todoRepository: any TodoEventRepository
    private let scheduleRepository: any ScheduleEventRepository
    private let holidayFetchUsecase: any HolidaysFetchUsecase
    private let eventTagRepository: any EventTagRepository
    
    init(
        todoRepository: any TodoEventRepository,
        scheduleRepository: any ScheduleEventRepository,
        holidayFetchUsecase: any HolidaysFetchUsecase,
        eventTagRepository: any EventTagRepository
    ) {
        self.todoRepository = todoRepository
        self.scheduleRepository = scheduleRepository
        self.holidayFetchUsecase = holidayFetchUsecase
        self.eventTagRepository = eventTagRepository
    }
    
    private actor Cached {
        var offTagIds: Set<AllEventTagId>?
        var currentTodos: [TodoCalendarEvent]?
        var allCustomTagsMap: [String: EventTag]?
        
        func updateOffTagIds(_ ids: Set<AllEventTagId>) {
            self.offTagIds = ids
        }
        func updateCurrentTodos(_ todos: [TodoCalendarEvent]) {
            self.currentTodos = todos
        }
        func updateAllCustomTagsMap(_ newValue: [String: EventTag]) {
            self.allCustomTagsMap = newValue
        }
        func reset() {
            self.offTagIds = nil
            self.currentTodos = nil
        }
    }
    private let cached = Cached()
}

extension CalendarEventFetchUsecaseImple {
    
    func reset() async {
        await self.cached.reset()
    }
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        
        let offTagIds = await self.offTagIds()
        let customTagMap = try await self.allCustomEventTagMap()
        let currentTodos = try await self.currentTodoEvents(timeZone)
        let todosInRange = try await self.todoEvents(in: range, timeZone)
        let schedulesInRange = try await self.scheduleEvents(in: range, timeZone)
        let holidaysInRage = try await self.holidays(in: range, timeZone)
        
        let eventsWithTime: [any CalendarEvent] = todosInRange + schedulesInRange + holidaysInRage
        
        let events = CalendarEvents(
            currentTodos: currentTodos.filter { !offTagIds.contains($0.eventTagId) },
            eventWithTimes: eventsWithTime.filter { !offTagIds.contains($0.eventTagId) }.sorted(),
            customTagMap: customTagMap
        )
        return events
    }
    
    private func offTagIds() async -> Set<AllEventTagId> {
        if let cached = await self.cached.offTagIds {
            return cached
        }
        let ids = self.eventTagRepository.loadOffTags()
        await self.cached.updateOffTagIds(ids)
        return ids
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
        return events.filter { $0.eventTime?.isOverlap(with: range) ?? false }
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
