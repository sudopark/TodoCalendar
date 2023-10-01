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


// MARK: - DayEventListViewModel

protocol DayEventListViewModel: AnyObject, Sendable, DayEventListSceneInteractor {

    // interactor
    func selectEvent(_ model: any EventCellViewModel)
    func doneTodo(_ eventId: String)
    func addNewTodoQuickly(withName: String)
    func makeTodoEvent(with givenName: String)
    func makeEvent()
    func makeEventByTemplate()
    
    // presenter
    var selectedDay: AnyPublisher<String, Never> { get }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> { get }
    var doneTodoFailed: AnyPublisher<String, Never> { get }
}


// MARK: - DayEventListViewModelImple

final class DayEventListViewModelImple: DayEventListViewModel, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let todoEventUsecase: any TodoEventUsecase
    private let scheduleEventUsecase: any ScheduleEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    var router: (any DayEventListRouting)?
    
    init(
        calendarSettingUsecase: any CalendarSettingUsecase,
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        eventTagUsecase: any EventTagUsecase
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
        let doneFailedTodo = PassthroughSubject<String, Never>()
        let pendingTodoEvents = CurrentValueSubject<[PendingTodoEventCellViewModel], Never>([])
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
    
    func selectEvent(_ model: any EventCellViewModel) {
        // TODO: show detail
    }
    
    func doneTodo(_ eventId: String) {
        Task { [weak self] in
            do {
                _ = try await self?.todoEventUsecase.completeTodo(eventId)
            } catch {
                self?.subject.doneFailedTodo.send(eventId)
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    func addNewTodoQuickly(withName: String) {
        let newPendingTodo = PendingTodoEventCellViewModel(
            name: withName, defaultTagId: nil
        )
        self.updatePendingTodos { $0 + [newPendingTodo] }
        
        let params = TodoMakeParams() |> \.name .~ withName
        Task { [weak self] in
            do {
                _ = try await self?.todoEventUsecase.makeTodoEvent(params)
            } catch let error {
                self?.router?.showError(error)
            }
            self?.updatePendingTodos {
                $0.filter { $0.eventIdentifier != newPendingTodo.eventIdentifier }
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func updatePendingTodos(
        _ mutating: ([PendingTodoEventCellViewModel]) -> [PendingTodoEventCellViewModel]
    ) {
        let old = self.subject.pendingTodoEvents.value
        let new = mutating(old)
        self.subject.pendingTodoEvents.send(new)
    }
    
    func makeTodoEvent(with givenName: String) {
        let params = TodoMakeParams()
            |> \.name .~ givenName
        self.router?.routeToMakeTodoEvent(params)
    }
    
    func makeEvent() {
        self.router?.routeToMakeNewEvent()
    }
    
    func makeEventByTemplate() {
        self.router?.routeToSelectTemplateForMakeEvent()
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
    
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> {
        
        let applyTag: ([any EventCellViewModel], [String: EventTag]) -> [any EventCellViewModel]
        applyTag = { cellViewModels, tagMap in
            return cellViewModels.map { cellViewModel in
                let tag = cellViewModel.tagId.flatMap { tagMap[$0] }
                var cellViewModel = cellViewModel
                cellViewModel.applyTagColor(tag)
                return cellViewModel
            }
        }
        return Publishers.CombineLatest(
            self.cellViewModelsFromEvent,
            self.subject.tagMaps
        )
        .map(applyTag)
        .removeDuplicates(by: { $0.map { $0.customCompareKey } == $1.map { $0.customCompareKey } })
        .eraseToAnyPublisher()
    }
    
    private var cellViewModelsFromEvent: AnyPublisher<[any EventCellViewModel], Never> {
        
        let asCellViewModel: (
            (CurrentDayAndIdLists, TimeZone, AllTodos, [String: ScheduleEvent]), [PendingTodoEventCellViewModel]
        ) -> [any EventCellViewModel]
        asCellViewModel = { tuple, pendings in
            
            let (dayAndIds, timeZone, allTodos, scheduleMap) = (tuple.0, tuple.1, tuple.2, tuple.3)
            
            let range = dayAndIds.currentDay.range
            let currentTodoCells = allTodos.currentTodoIds
                .compactMap { allTodos.allTodoMap[$0] }
                .compactMap { TodoEventCellViewModel($0, in: range, timeZone) }
            
            let eventCellsWithTime = dayAndIds.eventIds.compactMap { eventId -> (any EventCellViewModel)? in
                switch eventId {
                case .todo(let id):
                    return allTodos.allTodoMap[id]
                        .flatMap { TodoEventCellViewModel($0, in: range, timeZone) }
                case .schedule(let id, let turn):
                    return scheduleMap[id]
                        .flatMap { ScheduleEventCellViewModel($0, turn: turn, in: range, timeZone: timeZone) }
                case .holiday(let holiday):
                    return HolidayEventCellViewModel(holiday)
                }
            }
            
            return currentTodoCells + pendings + eventCellsWithTime
        }
        
        return Publishers.CombineLatest4(
            self.subject.currentDayAndIdLists.compactMap { $0 },
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.allTodos.compactMap { $0 },
            self.subject.scheduleMap
        )
        .combineLatest(self.subject.pendingTodoEvents)
        .map(asCellViewModel)
        .eraseToAnyPublisher()
    }
    
    var doneTodoFailed: AnyPublisher<String, Never> {
        return self.subject.doneFailedTodo
            .eraseToAnyPublisher()
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
