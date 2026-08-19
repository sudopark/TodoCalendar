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

    // todo, schedule, timeZone, foremost, 태그 필터 미적용
    func allCalendarEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[any CalendarEvent], Never>

    // current todo, foremost
    func currentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never>

    // current todo, foremost, 태그 필터 미적용
    func allCurrentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never>

    // showUncompletedTodos, uncompleted todo, foremost, timeZone
    func uncompletedTodos() -> AnyPublisher<[TodoCalendarEvent], Never>
}


private struct WritableCalendarIds: Equatable {
    var google: [String: Set<String>] = [:]
    var apple: Set<String> = []
}

final class CalendarEventListhUsecaseImple: CalendarEventListhUsecase, @unchecked Sendable {

    private let todoUsecase: any TodoEventUsecase
    private let scheduleUsecase: any ScheduleEventUsecase
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let appleCalendarUsecase: any AppleCalendarUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase

    init(
        todoUsecase: any TodoEventUsecase,
        scheduleUsecase: any ScheduleEventUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        appleCalendarUsecase: any AppleCalendarUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventTagUsecase: any EventTagUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.todoUsecase = todoUsecase
        self.scheduleUsecase = scheduleUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
        self.appleCalendarUsecase = appleCalendarUsecase
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
        let writableCalendarIds = CurrentValueSubject<WritableCalendarIds, Never>(.init())
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

        Publishers.CombineLatest(
            self.googleCalendarUsecase.calendarTags,
            self.appleCalendarUsecase.calendarTags
        )
        .map { googleTags, appleTags -> WritableCalendarIds in
            let google = googleTags
                .filter { $0.isWritable }
                .reduce(into: [String: Set<String>]()) { acc, tag in
                    acc[tag.ownerId, default: []].insert(tag.id)
                }
            let apple = Set(appleTags.filter { $0.isWritable == true }.map { $0.id })
            return WritableCalendarIds(google: google, apple: apple)
        }
        .sink(receiveValue: { [weak self] ids in
            self?.subject.writableCalendarIds.send(ids)
        })
        .store(in: &self.cancellables)
    }
}

extension CalendarEventListhUsecaseImple {

    func calendarEvents(in range: Range<TimeInterval>) -> AnyPublisher<[any CalendarEvent], Never> {
        return self.calendarEventsPublisher(from: self.activeCalendarEventTuple(in: range))
    }

    func allCalendarEvents(in range: Range<TimeInterval>) -> AnyPublisher<[any CalendarEvent], Never> {
        return self.calendarEventsPublisher(from: self.rawCalendarEventTuple(in: range))
    }

    private typealias CalendarEventTuple = ([TodoEvent], [ScheduleEvent], [GoogleCalendar.Event], [AppleCalendar.Event])

    private func calendarEventsPublisher(
        from tuplePublisher: AnyPublisher<CalendarEventTuple, Never>
    ) -> AnyPublisher<[any CalendarEvent], Never> {
        let foremost = self.subject.foremostEvent.map { event in
            return event.map { ForemostEventId(event: $0) }
        }
        let transform: (
            CalendarEventTuple, ForemostEventId?, TimeZone, WritableCalendarIds
        ) -> [any CalendarEvent] = { events, foremostId, timeZone, writableIds in
            let (todos, schedules, googles, apples) = events
            let todoEvents = todos.compactMap {
                TodoCalendarEvent($0, in: timeZone, isForemost: foremostId?.eventId == $0.uuid)
            }
            let scheduleEvents = schedules.flatMap {
                ScheduleCalendarEvent.events(from: $0, in: timeZone, foremostId: foremostId?.eventId)
            }
            let googleEvents = googles.map {
                GoogleCalendarEvent($0, in: timeZone, isWritable: writableIds.google[$0.accountId]?.contains($0.calendarId) == true)
            }
            let appleEvents = apples.map {
                AppleCalendarEvent($0, in: timeZone, isWritable: writableIds.apple.contains($0.calendarId))
            }
            return todoEvents + scheduleEvents + googleEvents + appleEvents
        }

        return Publishers.CombineLatest4(
            tuplePublisher,
            foremost,
            self.subject.timeZone.compactMap { $0 },
            self.subject.writableCalendarIds
        )
        .map(transform)
        .removeDuplicates(by: { $0.map { $0.compareKey } == $1.map { $0.compareKey } })
        .eraseToAnyPublisher()
    }

    private func rawCalendarEventTuple(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<CalendarEventTuple, Never> {
        return Publishers.CombineLatest4(
            self.todoUsecase.todoEvents(in: range),
            self.scheduleUsecase.scheduleEvents(in: range),
            self.googleCalendarUsecase.eventsWithoutCanceled(in: range),
            self.appleCalendarUsecase.events(in: range)
        )
        .map { ($0, $1, $2, $3) }
        .eraseToAnyPublisher()
    }

    private func activeCalendarEventTuple(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<CalendarEventTuple, Never> {

        let transform: (CalendarEventTuple, Set<EventTagId>) -> CalendarEventTuple = { tuple, offIds in
            let todos = tuple.0.filter { offIds.notContains($0.eventTagId) }
            let schedules = tuple.1.filter { offIds.notContains($0.eventTagId) }
            let googles = tuple.2.filter { offIds.notContains($0.eventTagId) }
            let apples = tuple.3.filter { offIds.notContains($0.eventTagId) }
            return (todos, schedules, googles, apples)
        }

        return Publishers.CombineLatest(
            self.rawCalendarEventTuple(in: range),
            self.subject.offTagIds
        )
        .map(transform)
        .eraseToAnyPublisher()
    }

    func currentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never> {
        return self.currentTodoEventsPublisher(from: self.activeCurrentTodos())
    }

    func allCurrentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never> {
        return self.currentTodoEventsPublisher(from: self.todoUsecase.currentTodoEvents)
    }

    private func currentTodoEventsPublisher(
        from todosPublisher: AnyPublisher<[TodoEvent], Never>
    ) -> AnyPublisher<[TodoCalendarEvent], Never> {
        let transform: ([TodoEvent], (any ForemostMarkableEvent)?) -> [TodoCalendarEvent]
        transform = { todos, foremost in
            return todos.map { TodoCalendarEvent(current: $0, isForemost: $0.uuid == foremost?.eventId) }
        }

        return Publishers.CombineLatest(
            todosPublisher,
            self.subject.foremostEvent
        )
        .map(transform)
        .removeDuplicates(by: { $0.map { $0.compareKey } == $1.map { $0.compareKey }})
        .eraseToAnyPublisher()
    }

    private func activeCurrentTodos() -> AnyPublisher<[TodoEvent], Never> {
        let transform: ([TodoEvent], Set<EventTagId>) -> [TodoEvent]
        transform = { todos, offIds in
            return todos.filter { offIds.notContains($0.eventTagId) }
        }

        return Publishers.CombineLatest(
            self.todoUsecase.currentTodoEvents,
            self.subject.offTagIds
        )
        .map(transform)
        .eraseToAnyPublisher()
    }

    func uncompletedTodos() -> AnyPublisher<[TodoCalendarEvent], Never> {
        let transform: ([TodoEvent], (any ForemostMarkableEvent)?, TimeZone) -> [TodoCalendarEvent]
        transform = { todos, foremost, timeZone in
            return todos.compactMap {
                TodoCalendarEvent($0, in: timeZone, isForemost: $0.uuid == foremost?.eventId )
            }
            .sortedByCreateTime()
        }
        return Publishers.CombineLatest3(
            self.activeUncompletedTodos(),
            self.subject.foremostEvent,
            self.subject.timeZone.compactMap{ $0 }
        )
        .map(transform)
        .removeDuplicates(by: { $0.map { $0.compareKey } == $1.map { $0.compareKey }})
        .eraseToAnyPublisher()
    }
    
    private func activeUncompletedTodos() -> AnyPublisher<[TodoEvent], Never> {
        let transform: (Bool, [TodoEvent], Set<EventTagId>) -> [TodoEvent]
        transform = { isOn, todos, offIds in
            guard isOn else { return [] }
            return todos.filter { !offIds.contains($0.eventTagId ?? .default) }
        }
        return Publishers.CombineLatest3(
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.showUncompletedTodos },
            self.todoUsecase.uncompletedTodos,
            self.subject.offTagIds
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
}

private extension GoogleCalendarUsecase {
    
    func eventsWithoutCanceled(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], Never> {
        return self.events(in: period)
            .map { events in
                return events.filter { $0.status != .cancelled }
            }
            .eraseToAnyPublisher()
    }
}

private extension Set where Element == EventTagId {
    
    func notContains(_ id: EventTagId?) -> Bool {
        return !self.contains(id ?? .default)
    }
}
