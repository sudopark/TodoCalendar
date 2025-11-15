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
    var customTagMap: [String: CustomEventTag]
    var googleCalendarColors: GoogleCalendar.Colors?
    var googleCalendarTags: [String: GoogleCalendar.Tag] = [:]
    
    init() {
        self.currentTodos = []
        self.eventWithTimes = []
        self.customTagMap = [:]
    }
    
    func findFirstFutureEvent(from time: TimeInterval, todayRange: Range<TimeInterval>) -> (any CalendarEvent)? {
        return self.eventWithTimes.first(where: {
            self.isTodayNextEvent($0, time, todayRange)
        })
    }
    
    func findNextEvents(
        from time: TimeInterval, todayRange: Range<TimeInterval>
    ) -> [any CalendarEvent] {
        return self.eventWithTimes.filter {
            self.isTodayNextEvent($0, time, todayRange)
        }
    }
    
    private func isTodayNextEvent(
        _ event: any CalendarEvent, _ current: TimeInterval, _ todayRange: Range<TimeInterval>
    ) -> Bool {
        guard !(event is HolidayCalendarEvent),
                let eventTime = event.eventTime,
              todayRange ~= eventTime.lowerBoundWithFixed
        else { return false }
        return eventTime.lowerBoundWithFixed > current
    }
}

struct ForemostEvent {
    let foremostEvent: (any ForemostMarkableEvent)?
    let tag: CustomEventTag?
}

struct TodayNextEvent {
    let nextEvent: any CalendarEvent
    let tag: CustomEventTag?
    var andThenNextEventStartDate: Date?
}

struct TodayNextEvents {
    let nextEvents: [any CalendarEvent]
    let customTags: [CustomEventTag]
}

protocol CalendarEventFetchUsecase {
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone,
        withoutOffTagIds: Bool
    ) async throws -> CalendarEvents
    
    func fetchForemostEvent() async throws -> ForemostEvent
    
    func fetchNextEvent(
        _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvent?
    
    func fetchNextEvents(
        _ refTime: Date, withIn todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvents
}

extension CalendarEventFetchUsecase {
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        return try await self.fetchEvents(in: range, timeZone, withoutOffTagIds: false)
    }
}


// MARK: - CalendarEventFetchUsecaseImple

actor CalendarEventsFetchCacheStore {
    
    struct Storage {
        var currentTodos: [TodoCalendarEvent]?
        var allCustomTagsMap: [String: CustomEventTag]?
        var externalAccountMap: [String: ExternalServiceAccountinfo]?
        var googleCalendarColors: GoogleCalendar.Colors?
        var googleCalendarTags: [String: GoogleCalendar.Tag]?
        var eventDetails: [String: EventDetailData] = [:]
    }
    
    private var storage = Storage()
    
    func update<T>(_ keyPath: WritableKeyPath<CalendarEventsFetchCacheStore.Storage, T>, _ newValue: T) {
        self.storage[keyPath: keyPath] = newValue
    }
    
    func update<T>(
        _ keyPath: WritableKeyPath<CalendarEventsFetchCacheStore.Storage, T>,
        mutate: (T) -> T
    ) {
        let oldValue = self.storage[keyPath: keyPath]
        let newValue = mutate(oldValue)
        self.storage[keyPath: keyPath] = newValue
    }
    
    func value<T>(
        _ keyPath: KeyPath<CalendarEventsFetchCacheStore.Storage, T>
    ) -> T {
        return self.storage[keyPath: keyPath]
    }

    func reset() {
        self.storage = .init()
    }
    
    func resetCurrentTodo() {
        self.storage.currentTodos = nil
    }
}


final class CalendarEventFetchUsecaseImple: CalendarEventFetchUsecase, @unchecked Sendable {
    
    private let todoRepository: any TodoEventRepository
    private let scheduleRepository: any ScheduleEventRepository
    private let foremostEventRepository: any ForemostEventRepository
    private let holidayFetchUsecase: any HolidaysFetchUsecase
    private let eventTagRepository: any EventTagRepository
    private let externalCalendarIntegrateRepository: any ExternalCalendarIntegrateRepository
    private let googleCalendarRepository: any GoogleCalendarRepository
    private let eventDetailRepository: any EventDetailDataRepository
    private let cached: CalendarEventsFetchCacheStore
    
    init(
        todoRepository: any TodoEventRepository,
        scheduleRepository: any ScheduleEventRepository,
        foremostEventRepository: any ForemostEventRepository,
        holidayFetchUsecase: any HolidaysFetchUsecase,
        eventTagRepository: any EventTagRepository,
        externalCalendarIntegrateRepository: any ExternalCalendarIntegrateRepository,
        googleCalendarRepository: any GoogleCalendarRepository,
        eventDetailRepository: any EventDetailDataRepository,
        cached: CalendarEventsFetchCacheStore
    ) {
        self.todoRepository = todoRepository
        self.scheduleRepository = scheduleRepository
        self.foremostEventRepository = foremostEventRepository
        self.holidayFetchUsecase = holidayFetchUsecase
        self.eventTagRepository = eventTagRepository
        self.externalCalendarIntegrateRepository = externalCalendarIntegrateRepository
        self.googleCalendarRepository = googleCalendarRepository
        self.eventDetailRepository = eventDetailRepository
        self.cached = cached
    }
}

extension CalendarEventFetchUsecaseImple {
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone,
        withoutOffTagIds: Bool
    ) async throws -> CalendarEvents {
        
        let customTagMap = try await self.allCustomEventTagMap()
        let currentTodos = try await self.currentTodoEvents(timeZone)
        let todosInRange = try await self.todoEvents(in: range, timeZone)
        let schedulesInRange = try await self.scheduleEvents(in: range, timeZone)
        let holidaysInRage = try await self.holidays(in: range, timeZone)
        
        var eventsWithTime: [any CalendarEvent] = todosInRange + schedulesInRange + holidaysInRage
        
        var events = CalendarEvents()
        events.currentTodos = currentTodos
        events.customTagMap = customTagMap
        
        if await self.checkGoogleCalendarIntegrated() {
            events.googleCalendarColors = try await self.googleCalendarColors()
            let tags = try await self.googleCalendarTags()
            events.googleCalendarTags = tags
            
            let allTagIds = Array(tags.keys)
            let googleEvents = try await self.googleCalendarEvents(allTagIds, in: range, timeZone)
            eventsWithTime += googleEvents
        }
        
        events.eventWithTimes = eventsWithTime.sorted()
        
        if withoutOffTagIds {
            let offIds = self.eventTagRepository.loadOffTags()
            events.currentTodos = events.currentTodos.filter {
                !offIds.contains($0.eventTagId)
            }
            events.eventWithTimes = events.eventWithTimes.filter {
                !offIds.contains($0.eventTagId)
            }
        }
        
        return events
    }

    private func allCustomEventTagMap() async throws -> [String: CustomEventTag] {
        if let cached = await self.cached.value(\.allCustomTagsMap) {
            return cached
        }
        let tags = try await self.eventTagRepository.loadAllCustomTags()
            .values.first(where: { _ in true }) ?? []
        let tagMap = tags.asDictionary { $0.uuid }
        await self.cached.update(\.allCustomTagsMap, tagMap)
        return tagMap
    }
    
    private func checkGoogleCalendarIntegrated() async -> Bool {
        let serviceId = GoogleCalendarService.id
        if let cached = await self.cached.value(\.externalAccountMap) {
            return cached[serviceId] != nil
        }
        let accounts = (try? await self.externalCalendarIntegrateRepository.loadIntegratedAccounts()) ?? []
        let accountMap = accounts.asDictionary{ $0.serviceIdentifier }
        await self.cached.update(\.externalAccountMap, accountMap)
        return accountMap[serviceId] != nil
    }
    
    private func googleCalendarColors() async throws -> GoogleCalendar.Colors {
        if let cached = await self.cached.value(\.googleCalendarColors) {
            return cached
        }
        let colors = try await self.googleCalendarRepository.loadColors()
            .values.first(where: { _ in true }) ?? .init(calendars: [:], events: [:])
        await self.cached.update(\.googleCalendarColors, colors)
        return colors
    }
    
    private func googleCalendarTags() async throws -> [String: GoogleCalendar.Tag] {
        if let cached = await self.cached.value(\.googleCalendarTags) {
            return cached
        }
        let tags = try await self.googleCalendarRepository.loadCalendarTags()
            .values.first(where: { _ in true }) ?? []
        let tagMap = tags.asDictionary { $0.id }
        await self.cached.update(\.googleCalendarTags, tagMap)
        return tagMap
    }
    
    private func currentTodoEvents(
        _ timeZone: TimeZone
    ) async throws -> [TodoCalendarEvent] {
        if let cached = await self.cached.value(\.currentTodos) {
            return cached
        }
        let todos = (try await self.todoRepository.loadCurrentTodoEvents()
            .values.first(where: { _ in true }) ?? [])
            .map { TodoCalendarEvent($0, in: timeZone) }
        await self.cached.update(\.currentTodos, todos)
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
        let eventContainer = MemorizedEventsContainer<ScheduleEvent>()
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
    
    private func googleCalendarEvents(
        _ calendarIds: [String],
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [GoogleCalendarEvent] {
        let events = try await calendarIds.async.reduce(into: [GoogleCalendar.Event]()) { [weak self] acc, id in
            
            let list = try await self?.googleCalendarRepository.loadEvents(id, in: range)
                .values.first(where: { _ in true }) ?? []
            acc += list
        }
        let calendarEvents = events.map { GoogleCalendarEvent($0, in: timeZone) }
        return calendarEvents
    }
    
    private func fetchLocationInfoIfNeed(_ event: any CalendarEvent) async throws -> Place? {
        
        guard let todoOrScheduleId = switch event {
        case let todo as TodoCalendarEvent: todo.eventId
        case let schedule as ScheduleCalendarEvent: schedule.eventIdWithoutTurn
        default: nil
        } else { return nil }
        
        if let cached = await self.cached.value(\.eventDetails)[todoOrScheduleId] {
            return cached.place
        }
        
        let detail = try await self.eventDetailRepository.loadDetail(todoOrScheduleId).values.first(where: { _ in true })
        await self.cached.update(\.eventDetails) { old in old |> key(todoOrScheduleId) .~ detail }
        return detail?.place
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
        
        let events = try await self.fetchEvents(in: todayRange, timeZone, withoutOffTagIds: true)
        
        guard var firstFutureEvent = events.findFirstFutureEvent(from: refTime.timeIntervalSince1970, todayRange: todayRange)
        else {
            return nil
        }
        let place = try? await self.fetchLocationInfoIfNeed(firstFutureEvent)
        firstFutureEvent.locationText = place?.placeName
        
        let secondFutureEvent = firstFutureEvent.eventTime.flatMap {
            return events.findFirstFutureEvent(from: $0.lowerBoundWithFixed, todayRange: todayRange)
        }
        let tag = firstFutureEvent.eventTagId.customTagId.flatMap {
            return events.customTagMap[$0]
        }
        
        return TodayNextEvent(nextEvent: firstFutureEvent, tag: tag)
            |> \.andThenNextEventStartDate .~ secondFutureEvent?.eventTime.map {
                Date(timeIntervalSince1970: $0.lowerBoundWithFixed)
            }
    }
    
    func fetchNextEvents(
        _ refTime: Date, withIn todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvents {
        
        let events = try await self.fetchEvents(in: todayRange, timeZone, withoutOffTagIds: true)
        let todayEvents = events.findNextEvents(
            from: refTime.timeIntervalSince1970, todayRange: todayRange
        )
        
        let customTags = todayEvents
            .compactMap { $0.eventTagId.customTagId }
            .compactMap { events.customTagMap[$0] }
        
        return TodayNextEvents(nextEvents: todayEvents, customTags: customTags)
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
