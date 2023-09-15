//
//  
//  DayEventListViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes
import Extensions


struct EventCellViewModel: Equatable {
    
    let eventId: EventId
    var isTodo: Bool {
        guard case .todo = self.eventId else { return false }
        return true
    }
    
    enum PeriodText: Equatable {
        case anyTime
        case allDay
        case atTime(_ timeText: String)
        case inToday(_ startTime: String, _ endTime: String)
        case fromTodayToFuture(_ startTime: String, _ endDay: String)
        case fromPastToToday(_ startDay: String, _ endTime: String)
        
        init?(
            _ eventTime: EventTime,
            in todayRange: Range<TimeInterval>,
            timeZone: TimeZone
        ) {
            let eventTimeRange = eventTime.rangeWithShifttingifNeed(on: timeZone)
            let startTimeInToday = todayRange ~= eventTimeRange.lowerBound
            let endTimeInToday = todayRange ~= eventTimeRange.upperBound
            let isAllDay = eventTimeRange.lowerBound <= todayRange.lowerBound && todayRange.upperBound <= eventTimeRange.upperBound
            switch (eventTime, startTimeInToday, endTimeInToday, isAllDay) {
            case (_, _, _, true):
                self = .allDay
            case (.at(let time), true, true, _):
                self = .atTime(time.timeText(timeZone))
            case (_, true, true, _):
                self = .inToday(
                    eventTime.lowerBoundWithFixed.timeText(timeZone),
                    eventTime.upperBoundWithFixed.timeText(timeZone)
                )
            case (_, true, false, _):
                self = .fromTodayToFuture(
                    eventTime.lowerBoundWithFixed.timeText(timeZone),
                    eventTime.upperBoundWithFixed.dayText(timeZone)
                )
            case (_, false, true, _):
                self = .fromPastToToday(
                    eventTime.lowerBoundWithFixed.dayText(timeZone),
                    eventTime.upperBoundWithFixed.timeText(timeZone)
                )
            default:
                return nil
            }
        }
    }
    fileprivate var tagId: String?
    let name: String
    var periodText: PeriodText?
    var periodDescription: String?
    var colorHex: String?
    
    init(
        eventId: EventId,
        name: String
    ) {
        self.eventId = eventId
        self.name = name
    }
}

// MARK: - DayEventListViewModel

protocol DayEventListViewModel: AnyObject, Sendable, DayEventListSceneInteractor {

    // interactor
    func selectEvent(_ model: EventCellViewModel)
    func doneTodo(_ eventId: String)
    func addEvent()
    func addEventByTemplate()
    
    // presenter
    var selectedDay: AnyPublisher<String, Never> { get }
    var cellViewModels: AnyPublisher<[EventCellViewModel], Never> { get }
}


// MARK: - DayEventListViewModelImple

final class DayEventListViewModelImple: DayEventListViewModel, @unchecked Sendable {
    
    private let calendarSettingUsecase: CalendarSettingUsecase
    private let todoEventUsecase: TodoEventUsecase
    private let scheduleEventUsecase: ScheduleEventUsecase
    private let eventTagUsecase: EventTagUsecase
    var router: DayEventListRouting?
    
    init(
        calendarSettingUsecase: CalendarSettingUsecase,
        todoEventUsecase: TodoEventUsecase,
        scheduleEventUsecase: ScheduleEventUsecase,
        eventTagUsecase: EventTagUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.eventTagUsecase = eventTagUsecase
        
        self.internalBind()
    }
    
    
    private struct CurrentDayAndIdLists {
        let currentDay: CurrentSelectDayModel
        let eventIds: [EventId]
    }
    
    private struct AllTodos {
        let currentTodoIds: [String]
        let allTodoMap: [String: TodoEvent]
        init(_ currents: [TodoEvent], _ todoWithTime: [TodoEvent]) {
            self.currentTodoIds = currents.map { $0.uuid }
            self.allTodoMap = (currents + todoWithTime).asDictionary { $0.uuid }
        }
    }
    
    private struct Subject {
        let currentDayAndIdLists = CurrentValueSubject<CurrentDayAndIdLists?, Never>(nil)
        let allTodos = CurrentValueSubject<AllTodos?, Never>(nil)
        let todosMap = CurrentValueSubject<[String: TodoEvent], Never>([:])
        let scheduleMap = CurrentValueSubject<[String: ScheduleEvent], Never>([:])
        let tagMaps = CurrentValueSubject<[String: EventTag], Never>([:])
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBind() {
        
        self.bindEvents()
        self.bindTags()
    }
    
    private func bindEvents() {
        
        let todoWithTimes = self.subject.currentDayAndIdLists
            .compactMap { $0?.currentDay.range }
            .map { [weak self] range -> AnyPublisher<[TodoEvent], Never> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                return self.todoEventUsecase.todoEvents(in: range)
            }
            .switchToLatest()
        
        Publishers.CombineLatest(
            self.todoEventUsecase.currentTodoEvents,
            todoWithTimes
        )
        .map { AllTodos($0, $1) }
        .sink(receiveValue: { [weak self] allTodos in
            self?.subject.allTodos.send(allTodos)
        })
        .store(in: &self.cancellables)
        
        self.subject.currentDayAndIdLists
            .compactMap { $0?.currentDay.range }
            .map { [weak self] range -> AnyPublisher<[ScheduleEvent], Never> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                return self.scheduleEventUsecase.scheduleEvents(in: range)
            }
            .switchToLatest()
            .sink(receiveValue: { [weak self] schedules in
                self?.subject.scheduleMap.send(schedules.asDictionary { $0.uuid })
            })
            .store(in: &self.cancellables)
    }
    
    private func bindTags() {
        let tagIdsFromTodo = self.subject.allTodos
            .compactMap { todos in todos?.allTodoMap.values.compactMap { $0.eventTagId } }
        let tagIdsFromSchedule = self.subject.scheduleMap
            .map { schedules in schedules.compactMap { $0.value.eventTagId } }
        // TODO: 추후에 holiday용 태그도 로드해야함
        Publishers.CombineLatest(
            tagIdsFromTodo, tagIdsFromSchedule
        )
        .map { $0 + $1 }
        .map { [weak self] ids -> AnyPublisher<[String: EventTag], Never> in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.eventTagUsecase.eventTags(ids)
        }
        .switchToLatest()
        .sink(receiveValue: { [weak self] tagMap in
            self?.subject.tagMaps.send(tagMap)
        })
        .store(in: &self.cancellables)
    }
}


// MARK: - DayEventListViewModelImple Interactor

extension DayEventListViewModelImple {
    
    func selectedDayChanaged(
        _ newDay: CurrentSelectDayModel,
        and eventThatDay: [EventId]
    ) {
        self.subject.currentDayAndIdLists.send(
            .init(currentDay: newDay, eventIds: eventThatDay)
        )
    }
    
    func selectEvent(_ model: EventCellViewModel) {
        // TODO: show detail
    }
    
    func doneTodo(_ eventId: String) {
        Task { [weak self] in
            do {
                _ = try await self?.todoEventUsecase.completeTodo(eventId)
            } catch {
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    func addEvent() {
        // TODO: route to add event scene
    }
    
    func addEventByTemplate() {
        // TODO: route to select template scene
    }
}


// MARK: - DayEventListViewModelImple Presenter

extension DayEventListViewModelImple {
    
    var selectedDay: AnyPublisher<String, Never> {
        let transform: (TimeZone, CurrentSelectDayModel) -> String?
        transform = { timeZone, currentDay in
            let date = Date(timeIntervalSince1970: currentDay.range.lowerBound)
            let formatter = DateFormatter()
            formatter.timeZone = timeZone
            formatter.dateFormat = "EEEE, MMM d, yyyy".localized()
            return formatter.string(from: date)
        }
        return Publishers.CombineLatest(
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.currentDayAndIdLists.compactMap { $0?.currentDay }
        )
        .compactMap(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var cellViewModels: AnyPublisher<[EventCellViewModel], Never> {
        
        let applyTag: ([EventCellViewModel], [String: EventTag]) -> [EventCellViewModel]
        applyTag = { cellViewModels, tagMap in
            return cellViewModels.map { cellViewModel in
                guard let tagId = cellViewModel.tagId else { return cellViewModel }
                return cellViewModel |> \.colorHex .~ tagMap[tagId]?.colorHex
            }
        }
        return Publishers.CombineLatest(
            self.cellViewModelsFromEvent,
            self.subject.tagMaps
        )
        .map(applyTag)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    private var cellViewModelsFromEvent: AnyPublisher<[EventCellViewModel], Never> {
        
        let asCellViewModel: (
            CurrentDayAndIdLists, TimeZone, AllTodos, [String: ScheduleEvent]
        ) -> [EventCellViewModel]
        asCellViewModel = { dayAndIds, timeZone, allTodos, scheduleMap in
            
            let range = dayAndIds.currentDay.range
            let currentTodoCells = allTodos.currentTodoIds
                .compactMap { allTodos.allTodoMap[$0] }
                .compactMap { EventCellViewModel($0, in: range, timeZone) }
            let eventCellsWithTime = dayAndIds.eventIds.compactMap { eventId -> EventCellViewModel? in
                switch eventId {
                case .todo(let id):
                    return allTodos.allTodoMap[id]
                        .flatMap { .init($0, in: range, timeZone) }
                case .schedule(let id, let turn):
                    return scheduleMap[id]
                        .flatMap { .init($0, turn: turn, in: range, timeZone: timeZone) }
                case .holiday(let holiday):
                    return .init(holiday)
                }
            }
            
            return currentTodoCells + eventCellsWithTime
        }
        
        return Publishers.CombineLatest4(
            self.subject.currentDayAndIdLists.compactMap { $0 },
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.allTodos.compactMap { $0 },
            self.subject.scheduleMap
        )
        .map(asCellViewModel)
        .eraseToAnyPublisher()
    }
}


extension EventCellViewModel {
    
    init?(_ todo: TodoEvent, in todayRange: Range<TimeInterval>, _ timeZone: TimeZone) {
        self.eventId = .todo(todo.uuid)
        self.tagId = todo.eventTagId
        self.name = todo.name
        
        guard let time = todo.time else {
            self.periodText = .anyTime
            return
        }
        guard let periodText = PeriodText(time, in: todayRange, timeZone: timeZone)
        else { return nil }
        self.periodText = periodText
        self.periodDescription = time.durationText(timeZone)
    }
    
    init?(_ schedule: ScheduleEvent, turn: Int, in todayRange: Range<TimeInterval>, timeZone: TimeZone) {
        guard let time = schedule.repeatingTimes.first(where: { $0.turn == turn }),
              let periodText = PeriodText(time.time, in: todayRange, timeZone: timeZone)
        else { return nil }
        self.eventId = .schedule(schedule.uuid, turn: turn)
        self.tagId = schedule.eventTagId
        self.name = schedule.name
        self.periodText = periodText
        self.periodDescription = time.time.durationText(timeZone)
    }
    
    init(_ holiday: Holiday) {
        self.eventId = .holiday(holiday)
        // TODO: set holiday tag
        self.name = holiday.localName
        self.periodText = .allDay
    }
}

private extension TimeInterval {
    
    func timeText(_ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "H:mm".localized()
        return formatter.string(from: Date(timeIntervalSince1970: self))
    }
    
    func dayText(_ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "d (E)".localized()
        return formatter.string(from: Date(timeIntervalSince1970: self))
    }
}

private extension EventTime {
    
    func durationText(_ timeZone: TimeZone) -> String? {
        
        switch self {
        case .period(let range):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = "MMM d HH:mm"
            return "\(range.rangeText(formatter))(\(range.totalPeriodText()))"
            
        case .allDay(let range, let secondsFrom):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = "MMM d"
            let shifttingRange = range.shiftting(secondsFrom, to: timeZone)
            let days = Int(shifttingRange.upperBound-shifttingRange.lowerBound) / (24 * 3600)
            let totalPeriodText = days > 0 ? "%ddays".localized(with: days+1) : nil
            let rangeText = shifttingRange.rangeText(formatter)
            return totalPeriodText.map { "\(rangeText)(\($0))"}
            
        default: return nil
        }
    }
}

private extension Range where Bound == TimeInterval {
    
    func rangeText(_ formatter: DateFormatter) -> String {
        let start = formatter.string(from: Date(timeIntervalSince1970: self.lowerBound))
        let end = formatter.string(from: Date(timeIntervalSince1970: self.upperBound))
        return "\(start) ~ \(end)"
    }
    
    func totalPeriodText() -> String {
        let length = Int(self.upperBound - self.lowerBound)
        let days = length / (24 * 3600)
        let hours = length % (24 * 3600) / 3600
        let minutes = length % 3600 / 60
        
        switch (days, hours, minutes) {
        case let (d, h, m) where d == 0 && h == 0:
            return "%dminutes".localized(with: m)
        case let (d, h, _) where d == 0:
            return "%dhours".localized(with: h)
        case let (d, h, _):
            return "%ddays %dhours".localized(with: d, h)
        }
    }
}
