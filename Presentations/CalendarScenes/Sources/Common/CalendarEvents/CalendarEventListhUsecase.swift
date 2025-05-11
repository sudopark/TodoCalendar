//
//  CalendarEventListhUsecase.swift
//  CalendarScenes
//
//  Created by sudo.park on 5/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions

protocol CalendarEventListhUsecase: Sendable {
    
    // todo, schedule, timeZone, foremost
    func calendarEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[any CalendarEvent], Never>
    
    // current todo, foremost
    func currentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never>
    
    // showUncompletedTodos, uncompleted todo, foremost, timeZone
    func uncompletedTodos() -> AnyPublisher<[TodoCalendarEvent], Never>
}


final class CalendarEventListhUsecaseImple: CalendarEventListhUsecase, @unchecked Sendable {
    
    private let todoUsecase: any TodoEventUsecase
    private let scheduleUsecase: any ScheduleEventUsecase
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    
    init(
        todoUsecase: any TodoEventUsecase,
        scheduleUsecase: any ScheduleEventUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventTagUsecase: any EventTagUsecase,
        
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.todoUsecase = todoUsecase
        self.scheduleUsecase = scheduleUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.eventTagUsecase = eventTagUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
        
        self.internalBind()
    }
    
    private struct Subject {
        let foremostEvent = CurrentValueSubject<(any ForemostMarkableEvent)?, Never>(nil)
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let offTagIds = CurrentValueSubject<Set<EventTagId>, Never>([])
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
    
    private func internalBind() {
        
        self.foremostEventUsecase.foremostEvent
            .sink(receiveValue: { [weak self] event in
                self?.subject.foremostEvent.send(event)
            })
            .store(in: &self.cancellables)
        
        self.calendarSettingUsecase.currentTimeZone
            .sink(receiveValue: { [weak self] timeZone in
                self?.subject.timeZone.send(timeZone)
            })
            .store(in: &self.cancellables)
        
        self.eventTagUsecase.offEventTagIdsOnCalendar()
            .sink(receiveValue: { [weak self] ids in
                self?.subject.offTagIds.send(ids)
            })
            .store(in: &self.cancellables)
    }
}

extension CalendarEventListhUsecaseImple {
    
    func calendarEvents(in range: Range<TimeInterval>) -> AnyPublisher<[any CalendarEvent], Never> {
        let foremost = self.subject.foremostEvent.map { event in
            return event.map { ForemostEventId(event: $0) }
        }
        let transform: (
            CalendarEventTuple, ForemostEventId?, TimeZone
        ) -> [any CalendarEvent] = { events, foremostId, timeZone in
            let (todos, schedules, googles) = events
            let todoEvents = todos.compactMap {
                TodoCalendarEvent($0, in: timeZone, isForemost: foremostId?.eventId == $0.uuid)
            }
            let scheduleEvents = schedules.flatMap {
                ScheduleCalendarEvent.events(from: $0, in: timeZone, foremostId: foremostId?.eventId)
            }
            let googleEvents = googles.map { GoogleCalendarEvent($0, in: timeZone) }
            return todoEvents + scheduleEvents + googleEvents
        }
        
        return Publishers.CombineLatest3(
            self.activeCalendarEventTuple(in: range),
            foremost,
            self.subject.timeZone.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates(by:  { $0.map{ $0.compareKey } == $1.map{ $0.compareKey }})
        .eraseToAnyPublisher()
    }
    
    private typealias CalendarEventTuple = ([TodoEvent], [ScheduleEvent], [GoogleCalendar.Event])
    private func activeCalendarEventTuple(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<CalendarEventTuple, Never> {
        
        let transform: (CalendarEventTuple, Set<EventTagId>) -> CalendarEventTuple = { tuple, offIds in
            let todos = tuple.0.filter { offIds.notContains($0.eventTagId) }
            let schedules = tuple.1.filter { offIds.notContains($0.eventTagId) }
            let googles = tuple.2.filter { offIds.notContains($0.eventTagId) }
            return (todos, schedules, googles)
        }
        
        return Publishers.CombineLatest4(
            self.todoUsecase.todoEvents(in: range),
            self.scheduleUsecase.scheduleEvents(in: range),
            self.googleCalendarUsecase.events(in: range),
            self.subject.offTagIds
        )
        .map { (($0, $1, $2), $3) }
        .map(transform)
        .eraseToAnyPublisher()
    }
    
    func currentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never> {
        
        let transform: ([TodoEvent], (any ForemostMarkableEvent)?, Set<EventTagId>) -> [TodoCalendarEvent]
        transform = { todos, foremost, offIds in
            return todos
                .filter { offIds.notContains($0.eventTagId) }
                .map { TodoCalendarEvent(current: $0, isForemost: $0.uuid == foremost?.eventId) }
        }
        
        return Publishers.CombineLatest3(
            self.todoUsecase.currentTodoEvents,
            self.subject.foremostEvent,
            self.subject.offTagIds
        )
        .map(transform)
        .removeDuplicates(by: { $0.map { $0.compareKey } == $1.map { $0.compareKey }})
        .eraseToAnyPublisher()
    }
    
    func uncompletedTodos() -> AnyPublisher<[TodoCalendarEvent], Never> {
        return Empty().eraseToAnyPublisher()
    }
}

private extension Set where Element == EventTagId {
    
    func notContains(_ id: EventTagId?) -> Bool {
        return !self.contains(id ?? .default)
    }
}
