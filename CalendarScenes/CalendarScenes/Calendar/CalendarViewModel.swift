//
//  CalendarViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/05.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


// MARK: - cell, event and row model

enum EventId: Equatable {
    case todo(String)
    case schedule(String, turn: Int)
    case holiday(_ dateString: String, name: String)
    
    var isHoliday: Bool {
        guard case .holiday = self else { return false }
        return true
    }
}

struct DayCellViewModel: Equatable {
    
    let year: Int
    let month: Int
    let day: Int
    let isNotCurrentMonth: Bool
    
    init(year: Int, month: Int, day: Int, isNotCurrentMonth: Bool) {
        self.year = year
        self.month = month
        self.day = day
        self.isNotCurrentMonth = isNotCurrentMonth
    }
    
    enum EventSummary: Equatable {
        enum Bound {
            case start
            case end
            
            init?(_ weekDay: Int, _ weekDaysRangs: ClosedRange<Int>) {
                if weekDaysRangs == weekDay...weekDay {
                    return nil
                } else if weekDaysRangs.lowerBound == weekDay {
                    self = .start
                } else if weekDaysRangs.upperBound == weekDay {
                    self = .end
                } else {
                    return nil
                }
            }
        }
        case blank
        case event(EventId, Bound?)
    }
    var events: [EventSummary] = []
    
    var identifier: String {
        "\(year)-\(month)-\(day)"
    }
    
    init(_ day: CalendarComponent.Day, month: Int, stack: [[EventOnWeek]]) {
        self.year = day.year
        self.month = day.month
        self.day = day.day
        self.isNotCurrentMonth = day.month != month
        self.events = stack.map { eventsRow in
            let eventOnThisDay = eventsRow.first(where: { $0.weekDaysRange ~= day.weekDay })
            return eventOnThisDay.map { .event($0.eventId, .init(day.weekDay, $0.weekDaysRange)) } ?? .blank
        }
    }
}

struct WeekRowModel: Equatable {
    let days: [DayCellViewModel]
    
    init(_ week: CalendarComponent.Week, month: Int, stack: [[EventOnWeek]]) {
        self.days = week.days.map { day -> DayCellViewModel in
            return .init(day, month: month, stack: stack)
        }
    }
}

struct EventDetailModel: Equatable {
    
    let eventId: EventId
    let name: String
    let colorHex: String
}

// MARK: - CalendarViewModelImple

final class CalendarViewModelImple: @unchecked Sendable {
    
    private let calendarUsecase: CalendarUsecase
    private let calendarSettingUsecase: CalendarSettingUsecase
    private let todoUsecase: TodoEventUsecase
    private let scheduleEventUsecase: ScheduleEventUsecase
    
    init(
        calendarUsecase: CalendarUsecase,
        calendarSettingUsecase: CalendarSettingUsecase,
        todoUsecase: TodoEventUsecase,
        scheduleEventUsecase: ScheduleEventUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoUsecase = todoUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        
        self.internalBind()
    }
    
    private struct CurrentMonthInfo: Equatable {
        let timeZone: TimeZone
        let component: CalendarComponent
        let range: Range<TimeInterval>
    }
    
    private struct Subject: @unchecked Sendable {
        let currentMonthComponent = CurrentValueSubject<CalendarComponent?, Never>(nil)
        let currentMonthInfo = CurrentValueSubject<CurrentMonthInfo?, Never>(nil)
        // TODO: 추후에 identifier만 들고있는 걸로 수정 필요
        let todoEventsMap = CurrentValueSubject<[String: TodoEvent], Never>([:])
        let scheduleEventsMap = CurrentValueSubject<[String: ScheduleEvent], Never>([:])
        
        let userSelectedDay = CurrentValueSubject<DayCellViewModel?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
    private var currentMonthComponentsBinding: AnyCancellable?
    
    private func internalBind() {
        
        Publishers.CombineLatest(
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.currentMonthComponent.compactMap { $0 }
        )
        .sink(receiveValue: { [weak self] timeZone, component in
            guard let range = component.intervalRange(at: timeZone) else { return }
            let totalComponent = CurrentMonthInfo(timeZone: timeZone, component: component, range: range)
            self?.subject.currentMonthInfo.send(totalComponent)
        })
        .store(in: &self.cancellables)
    }
}


extension CalendarViewModelImple: CalendarInteractor {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        
        let current = self.subject.currentMonthComponent.value
        let shouldChange = current?.year != newMonth.year || current?.month != newMonth.month
        guard shouldChange else { return }
        
        self.currentMonthComponentsBinding?.cancel()
        self.currentMonthComponentsBinding = self.calendarUsecase
            .components(for: newMonth.month, of: newMonth.year)
            .sink(receiveValue: { [weak self] component in
                self?.subject.currentMonthComponent.send(component)
            })
    }
    
    func select(_ day: DayCellViewModel) {
        self.subject.userSelectedDay.send(day)
    }
}

extension CalendarViewModelImple {
    
    private func updateTodoMap() -> ([TodoEvent]) -> Void {
        return { [weak self] todos in
            self?.subject.todoEventsMap.send(todos.asDictionary { $0.uuid })
        }
    }
    
    private func updateScheduleMap() -> ([ScheduleEvent]) -> Void {
        return { [weak self] schedules in
            self?.subject.scheduleEventsMap.send(schedules.asDictionary { $0.uuid })
        }
    }
    
    private func calendarEvents(from info: CurrentMonthInfo) -> AnyPublisher<[CalendarEvent], Never> {
        
        let todos = self.todoUsecase.todoEvents(in: info.range)
            .handleEvents(receiveOutput: self.updateTodoMap())
        let schedules = self.scheduleEventUsecase.scheduleEvents(in: info.range)
            .handleEvents(receiveOutput: self.updateScheduleMap())
        let holidayCalenarEvents = info.component.holidayCalendarEvents(with: info.timeZone)
        let transform: ([TodoEvent], [ScheduleEvent]) -> [CalendarEvent]
        transform = { todos, schedules in
            let todoEvents = todos.compactMap { CalendarEvent($0) }
            let scheduleEvents = schedules.flatMap { CalendarEvent.events(from: $0) }
            return todoEvents + scheduleEvents + holidayCalenarEvents
        }
        
        return Publishers.CombineLatest(todos,schedules)
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    // TODO: vc or view에서 구독시에 subscribeOn 쓰는것으로
    // TODO: throttle 걸건지도
    var weekModels: AnyPublisher<[WeekRowModel], Never> {
        
        typealias CurrentMonthAndEvents = (CurrentMonthInfo, [CalendarEvent])
        
        let withCalendarEventsInThisMonth: (CurrentMonthInfo) -> AnyPublisher<CurrentMonthAndEvents, Never>
        withCalendarEventsInThisMonth = { [weak self] info in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.calendarEvents(from: info)
                .map { (info, $0) }
                .eraseToAnyPublisher()
        }
        
        let transform: (CurrentMonthInfo, [CalendarEvent]) -> [WeekRowModel]
        transform = { current, events in
            let stackBuilder = WeekEventStackBuilder(current.timeZone)
            return current.component.weeks.map { week -> WeekRowModel in
                let stack = stackBuilder.build(week, events: events).eventStacks
                return .init(week, month: current.component.month, stack: stack)
            }
        }
        
        return self.subject.currentMonthInfo.compactMap { $0 }
            .map(withCalendarEventsInThisMonth)
            .switchToLatest()
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var currentSelectDayIdentifier: AnyPublisher<String, Never> {
        let transform: (DayCellViewModel?, CalendarComponent.Day, CalendarComponent) -> String
        transform = { selected, today, thisMonth in
            switch (selected, today, thisMonth) {
            case (.some(let day), _, let m) where day.month == m.month && day.year == m.year:
                return day.identifier
            case (_, let t, let m) where t.month != m.month:
                return "\(m.year)-\(m.month)-1"
            case (_, let t, _):
                return "\(t.year)-\(t.month)-\(t.day)"
            }
        }
        return Publishers.CombineLatest3(
            self.subject.userSelectedDay,
            self.calendarUsecase.currentDay,
            self.subject.currentMonthComponent.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}


// MARK: - private extensions

private extension CalendarComponent {
    
    func intervalRange(at timeZone: TimeZone) -> Range<TimeInterval>? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let startDay = self.weeks.first?.days.first,
              let endDay = self.weeks.last?.days.last,
              let startDate = calendar.date(from: startDay).flatMap(calendar.startOfDay(for:)),
              let endDate = calendar.date(from: endDay).flatMap(calendar.endOfDay(for:))
        else { return nil }
        
        return startDate.timeIntervalSince1970..<endDate.timeIntervalSince1970
    }
    
    func holidayCalendarEvents(with timeZone: TimeZone) -> [CalendarEvent] {
        return self.weeks
            .flatMap { $0.days }
            .compactMap { $0.holiday }
            .compactMap { CalendarEvent($0, timeZone: timeZone) }
    }
}