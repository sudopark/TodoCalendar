//
//  SingleMonthViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/05.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - week components

struct WeekDayModel: Equatable {
    let symbol: String
    let isWeekEnd: Bool
    
    static func allModels() -> [WeekDayModel] {
        return [
            .init(symbol: "SUN", isWeekEnd: true),
            .init(symbol: "MON", isWeekEnd: false),
            .init(symbol: "TUE", isWeekEnd: false),
            .init(symbol: "WED", isWeekEnd: false),
            .init(symbol: "THU", isWeekEnd: false),
            .init(symbol: "FRI", isWeekEnd: false),
            .init(symbol: "SAT", isWeekEnd: true)
        ]
    }
}

struct DayCellViewModel: Equatable {
    
    let year: Int
    let month: Int
    let day: Int
    let isNotCurrentMonth: Bool
    let isWeekEnd: Bool
    let isHoliday: Bool
    
    init(
        year: Int,
        month: Int,
        day: Int,
        isNotCurrentMonth: Bool,
        isWeekEnd: Bool,
        isHoliday: Bool
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.isNotCurrentMonth = isNotCurrentMonth
        self.isWeekEnd = isWeekEnd
        self.isHoliday = isHoliday
    }
    
    var identifier: String {
        "\(year)-\(month)-\(day)"
    }
    
    init(_ day: CalendarComponent.Day, month: Int) {
        self.year = day.year
        self.month = day.month
        self.day = day.day
        self.isNotCurrentMonth = day.month != month
        self.isWeekEnd = DayOfWeeks(rawValue: day.weekDay)?.isWeekEnd == true
        self.isHoliday = day.holiday != nil
    }
}

struct WeekRowModel: Equatable {
    let id: String
    let days: [DayCellViewModel]
    
    init(_ id: String, _ days: [DayCellViewModel]) {
        self.id = id
        self.days = days
    }
    
    init(_ week: CalendarComponent.Week, month: Int) {
        self.id = week.id
        self.days = week.days.map { day -> DayCellViewModel in
            return .init(day, month: month)
        }
    }
}


// MARK: Event components

enum EventId: Equatable {
    case todo(String)
    case schedule(String, turn: Int)
    case holiday(_ dateString: String)
    
    var isHoliday: Bool {
        guard case .holiday = self else { return false }
        return true
    }
}

struct WeekEventLineModel: Equatable {
    
    var eventId: EventId { self.eventOnWeek.eventId }
    let eventOnWeek: EventOnWeek
    let colorHex: String
    
    init(_ eventOnWeek: EventOnWeek, _ tag: EventTag?) {
        self.eventOnWeek = eventOnWeek
        // TODO: 임시로 디폴트 색 지정
        self.colorHex = tag?.colorHex ?? "#0000FF"
    }
}

struct EventMoreModel: Equatable {
    let daySequence: Int
    let dayIdentifier: String
    let moreCount: Int
}

typealias WeekEventStackViewModel = [[WeekEventLineModel]]

extension WeekEventStackViewModel {
    
    func eventMores(with maxSize: Int) -> [EventMoreModel] {
        guard maxSize > 0, maxSize < self.count else { return [] }
        let willHiddenRows = self[maxSize...]
        let willHiddenEventsPerDaySeq = willHiddenRows.reduce(into: [Int: [WeekEventLineModel]]()) { acc, lines in
            lines.forEach { line in
                line.eventOnWeek.daysSequence.forEach {
                    acc[$0] = (acc[$0] ?? []) + [line]
                }
            }
        }
        return willHiddenEventsPerDaySeq.compactMap {
            guard let event = $0.value.first?.eventOnWeek,
                  let dayIdentifier = event.daysIdentifiers[safe: $0.key-1]
            else { return nil }
            return EventMoreModel(
                daySequence: $0.key,
                dayIdentifier: dayIdentifier,
                moreCount: $0.value.count
            )
        }
    }
}

// MARK: - SingleMonthViewModel

protocol SingleMonthViewModel: AnyObject, Sendable, SingleMonthSceneInteractor {
    
    func select(_ day: DayCellViewModel)
    
    var weekDays: AnyPublisher<[WeekDayModel], Never> { get }
    var weekModels: AnyPublisher<[WeekRowModel], Never> { get }
    var currentSelectDayIdentifier: AnyPublisher<String?, Never> { get }
    var todayIdentifier: AnyPublisher<String, Never> { get }
    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never>
}

// MARK: - SingleMonthViewModelImple

final class SingleMonthViewModelImple: SingleMonthViewModel, @unchecked Sendable {
    
    private let calendarUsecase: CalendarUsecase
    private let calendarSettingUsecase: CalendarSettingUsecase
    private let todoUsecase: TodoEventUsecase
    private let scheduleEventUsecase: ScheduleEventUsecase
    private let eventTagUsecase: EventTagUsecase
    
    init(
        calendarUsecase: CalendarUsecase,
        calendarSettingUsecase: CalendarSettingUsecase,
        todoUsecase: TodoEventUsecase,
        scheduleEventUsecase: ScheduleEventUsecase,
        eventTagUsecase: EventTagUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoUsecase = todoUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.eventTagUsecase = eventTagUsecase
        
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
        let userSelectedDay = CurrentValueSubject<DayCellViewModel?, Never>(nil)
        let eventStackMap = CurrentValueSubject<[String: WeekEventStack], Never>([:])
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
        
        typealias CurrentMonthAndEvent = (CurrentMonthInfo, [CalendarEvent])
        let withEventsInThisMonth: (CurrentMonthInfo) -> AnyPublisher<CurrentMonthAndEvent, Never>
        withEventsInThisMonth = { [weak self] month in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.calendarEvents(from: month)
                .map { (month, $0) }
                .eraseToAnyPublisher()
        }
        
        let arrangeEventStacks: (CurrentMonthAndEvent) -> [String: WeekEventStack]
        arrangeEventStacks = { pair in
            let (current, events) = pair
            let weeks = current.component.weeks
            let stackBuilder = WeekEventStackBuilder(current.timeZone)
            return weeks.reduce(into: [String: WeekEventStack]()) { acc, week in
                let stack = stackBuilder.build(week, events: events)
                acc[week.id] = stack
            }
        }
        self.subject.currentMonthInfo.compactMap { $0 }
            .map(withEventsInThisMonth)
            .switchToLatest()
            .map(arrangeEventStacks)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .sink(receiveValue: { [weak self] stackMap in
                self?.subject.eventStackMap.send(stackMap)
            })
            .store(in: &self.cancellables)
    }
}


extension SingleMonthViewModelImple {
    
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

extension SingleMonthViewModelImple {
    
    private func calendarEvents(from info: CurrentMonthInfo) -> AnyPublisher<[CalendarEvent], Never> {
        
        let todos = self.todoUsecase.todoEvents(in: info.range)
        let schedules = self.scheduleEventUsecase.scheduleEvents(in: info.range)
        let holidayCalenarEvents = info.component.holidayCalendarEvents(with: info.timeZone)
        let transform: ([TodoEvent], [ScheduleEvent]) -> [CalendarEvent]
        transform = { todos, schedules in
            let todoEvents = todos.compactMap { CalendarEvent($0, in: info.timeZone) }
            let scheduleEvents = schedules.flatMap { CalendarEvent.events(from: $0, in: info.timeZone) }
            return todoEvents + scheduleEvents + holidayCalenarEvents
        }
        
        return Publishers.CombineLatest(todos,schedules)
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        let models = WeekDayModel.allModels()
        let transform: (DayOfWeeks) -> [WeekDayModel] = { dayOfWeek in
            let startIndex = dayOfWeek.rawValue-1
            return (startIndex..<startIndex+7).map { index in
                return models[index % 7]
            }
        }
        return self.calendarSettingUsecase.firstWeekDay
            .map(transform)
            .eraseToAnyPublisher()
    }
    
    var weekModels: AnyPublisher<[WeekRowModel], Never> {

        let transform: (CurrentMonthInfo) -> [WeekRowModel]
        transform = { current in
            return current.component.weeks.map { week -> WeekRowModel in
                return .init(week, month: current.component.month)
            }
        }
        
        return self.subject.currentMonthInfo.compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var currentSelectDayIdentifier: AnyPublisher<String?, Never> {
        let transform: (DayCellViewModel?, CalendarComponent.Day, CalendarComponent) -> String?
        transform = { selected, today, thisMonth in
            switch (selected, today, thisMonth) {
            case (.some(let day), _, _):
                return day.identifier
            case (_, let t, let m) where t.month != m.month:
                return "\(m.year)-\(m.month)-1"
            default:
                return nil
            }
        }
        return Publishers.CombineLatest3(
            self.subject.userSelectedDay,
            self.calendarUsecase.currentDay.removeDuplicates(),
            self.subject.currentMonthComponent.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var todayIdentifier: AnyPublisher<String, Never> {
        return self.calendarUsecase.currentDay
            .map { "\($0.year)-\($0.month)-\($0.day)" }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        typealias StackAndTagMap = (WeekEventStack, [String: EventTag])
        let asStackAndTagMap: (WeekEventStack) -> AnyPublisher<StackAndTagMap, Never>
        asStackAndTagMap = { [weak self] stack in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            let tagIds = stack.eventStacks.flatMap { $0.compactMap { $0.eventTagId } }
            guard !tagIds.isEmpty
            else {
                return Just((stack, [:])).eraseToAnyPublisher()
            }

            return self.eventTagUsecase.eventTags(tagIds)
                .map { (stack, $0) }
                .eraseToAnyPublisher()
        }
        let asStakModel: (StackAndTagMap) -> WeekEventStackViewModel = { pair in
            return pair.0.eventStacks.map { events -> [WeekEventLineModel] in
                return events.map { event -> WeekEventLineModel in
                    let tag = event.eventTagId.flatMap { pair.1[$0] }
                    return WeekEventLineModel(event, tag)
                }
            }
        }
        return self.subject.eventStackMap
            .compactMap { $0[weekId] }
            .map(asStackAndTagMap)
            .switchToLatest()
            .map(asStakModel)
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
