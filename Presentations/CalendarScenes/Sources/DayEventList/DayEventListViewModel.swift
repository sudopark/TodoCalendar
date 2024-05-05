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


struct SelectedDayModel: Equatable {
    let dateText: String
    var holidayName: String?
    let lunarDateText: String
    
    init(dateText: String, lunarDateText: String) {
        self.dateText = dateText
        self.lunarDateText = lunarDateText
    }
    
    init(_ timeZone: TimeZone, currentModel: CurrentSelectDayModel) {
        let date = Date(timeIntervalSince1970: currentModel.range.lowerBound)
        
        let formatter = DateFormatter() |> \.timeZone .~ timeZone
        formatter.dateFormat = "yyyy MM dd (E)".localized()
        self.dateText = formatter.string(from: date)
        
        let lunarFormatter = DateFormatter() 
            |> \.timeZone .~ timeZone
            |> \.calendar .~ Calendar(identifier: .chinese)
        
        lunarFormatter.dateFormat = "MM dd".localized()
        self.lunarDateText = lunarFormatter.string(from: date)
        
        self.holidayName = currentModel.holiday?.localName
    }
}

// MARK: - DayEventListViewModel

protocol DayEventListViewModel: AnyObject, Sendable, DayEventListSceneInteractor {

    // interactor
    func selectEvent(_ model: any EventCellViewModel)
    func doneTodo(_ eventId: String)
    func cancelDoneTodo(_ eventId: String)
    func addNewTodoQuickly(withName: String)
    func makeTodoEvent(with givenName: String)
    func makeEvent()
    func makeEventByTemplate()
    
    // presenter
    var selectedDay: AnyPublisher<SelectedDayModel, Never> { get }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> { get }
    var doneTodoFailed: AnyPublisher<String, Never> { get }
}


// MARK: - DayEventListViewModelImple

final class DayEventListViewModelImple: DayEventListViewModel, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let todoEventUsecase: any TodoEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any DayEventListRouting)?
    
    init(
        calendarSettingUsecase: any CalendarSettingUsecase,
        todoEventUsecase: any TodoEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoEventUsecase = todoEventUsecase
        self.eventTagUsecase = eventTagUsecase
        self.uiSettingUsecase = uiSettingUsecase
        
        self.internalBind()
    }
    
    
    private struct CurrentDayAndEventLists {
        let currentDay: CurrentSelectDayModel
        let events: [any CalendarEvent]
    }
    
    private struct Subject {
        let currentDayAndEventLists = CurrentValueSubject<CurrentDayAndEventLists?, Never>(nil)
        let tagMaps = CurrentValueSubject<[String: EventTag], Never>([:])
        let doneFailedTodo = PassthroughSubject<String, Never>()
        let pendingTodoEvents = CurrentValueSubject<[PendingTodoEventCellViewModel], Never>([])
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private var todoCompleteTaskMap: [String: Task<Void, any Error>] = [:]
    private let subject = Subject()
    
    private func internalBind() {
        
        self.bindTags()
    }
    
    private func bindTags() {
        
        let customTagIdsFromCalenadrEvent = self.subject.currentDayAndEventLists
            .compactMap { $0?.events }
            .map { $0.compactMap { $0.eventTagId.customTagId } }
        let tagIdsFromCurrentTodo = self.todoEventUsecase.currentTodoEvents
            .map { $0.compactMap { $0.eventTagId?.customTagId } }
        
        Publishers.CombineLatest(
            customTagIdsFromCalenadrEvent, tagIdsFromCurrentTodo
        )
        .map { $0 + $1 }
        .map { [weak self] ids -> AnyPublisher<[String: EventTag], Never> in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.eventTagUsecase.eventTags(ids)
        }
        .switchToLatest()
        .removeDuplicates()
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
        and eventThatDay: [any CalendarEvent]
    ) {
        self.subject.currentDayAndEventLists.send(
            .init(currentDay: newDay, events: eventThatDay)
        )
    }
    
    func selectEvent(_ model: any EventCellViewModel) {
        // TODO: show detail
        switch model {
        case let todo as TodoEventCellViewModel:
            self.router?.routeToTodoEventDetail(todo.eventIdentifier)
        case let schedule as ScheduleEventCellViewModel:
            self.router?.routeToScheduleEventDetail(schedule.eventIdWithoutTurn)
        case let holiday as HolidayEventCellViewModel:
            // TODO:
            break
        default: break
        }
    }
    
    func doneTodo(_ eventId: String) {
        self.cancelDoneTodo(eventId)
        self.todoCompleteTaskMap[eventId] = Task { [weak self] in
            do {
                _ = try await self?.todoEventUsecase.completeTodo(eventId)
            } catch {
                self?.subject.doneFailedTodo.send(eventId)
                self?.router?.showError(error)
            }
        }
    }
    
    func cancelDoneTodo(_ eventId: String) {
        self.todoCompleteTaskMap[eventId]?.cancel()
        self.todoCompleteTaskMap[eventId] = nil
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
        guard let selectDate = self.currentDate else { return }
        let params = MakeEventParams(selectedDate: selectDate)
            |> \.initialTodoInfo .~ .init(name: givenName)
        self.router?.routeToMakeNewEvent(params)
    }
    
    func makeEvent() {
        guard let selectDate = self.currentDate else { return }
        let params = MakeEventParams(selectedDate: selectDate)
        self.router?.routeToMakeNewEvent(params)
    }
    
    func makeEventByTemplate() {
        self.router?.routeToSelectTemplateForMakeEvent()
    }
    
    private var currentDate: Date? {
        guard let current = self.subject.currentDayAndEventLists.value?.currentDay
        else { return nil }
        return Date(timeIntervalSince1970: current.range.lowerBound)
    }
}


// MARK: - DayEventListViewModelImple Presenter

extension DayEventListViewModelImple {
    
    var selectedDay: AnyPublisher<SelectedDayModel, Never> {
        let transform: (TimeZone, CurrentSelectDayModel) -> SelectedDayModel?
        transform = { timeZone, currentDay in
            return SelectedDayModel(timeZone, currentModel: currentDay)
        }
        return Publishers.CombineLatest(
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.currentDayAndEventLists.compactMap { $0?.currentDay }
        )
        .compactMap(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> {
        
        let applyTag: ([any EventCellViewModel], [String: EventTag]) -> [any EventCellViewModel]
        applyTag = { cellViewModels, tagMap in
            return cellViewModels.map { cellViewModel in
                let tag = cellViewModel.tagId.customTagId.flatMap { tagMap[$0] }
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
        .filterTagActivated(self.eventTagUsecase) { $0.tagId }
        .removeDuplicates(by: { $0.map { $0.customCompareKey } == $1.map { $0.customCompareKey } })
        .eraseToAnyPublisher()
    }
    
    private typealias CurrentAndEvents = ([any EventCellViewModel], [any EventCellViewModel])
    
    private var currentAndEventCellViewModels: AnyPublisher<CurrentAndEvents, Never> {
        let asCellViewModel: (
            CurrentDayAndEventLists, TimeZone, [TodoEvent], Bool
        ) -> CurrentAndEvents
        asCellViewModel = { dayAndEvents, timeZone, currentTodos, is24HourForm in
            
            let range = dayAndEvents.currentDay.range
            let currentTodoCells = currentTodos
                .compactMap { TodoCalendarEvent($0, in: timeZone) }
                .compactMap { TodoEventCellViewModel($0, in: range, timeZone, is24HourForm) }
            
            let eventCellsWithTime = dayAndEvents.events.compactMap { event -> (any EventCellViewModel)? in
                switch event {
                case let todo as TodoCalendarEvent:
                    return TodoEventCellViewModel(todo, in: range, timeZone, is24HourForm)
                    
                case let schedule as ScheduleCalendarEvent:
                    return ScheduleEventCellViewModel(schedule, in: range, timeZone: timeZone, is24HourForm)
                case let holiday as HolidayCalendarEvent:
                    return HolidayEventCellViewModel(holiday)
                
                default: return nil
                }
            }
            
            return (currentTodoCells, eventCellsWithTime)
        }
        
        return Publishers.CombineLatest4(
            self.subject.currentDayAndEventLists.compactMap { $0 },
            self.calendarSettingUsecase.currentTimeZone,
            self.todoEventUsecase.currentTodoEvents,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }.removeDuplicates()
        )
        .map(asCellViewModel)
        .eraseToAnyPublisher()
    }
    
    private var cellViewModelsFromEvent: AnyPublisher<[any EventCellViewModel], Never> {
        
        let combineEvents: (CurrentAndEvents, [PendingTodoEventCellViewModel]) -> [any EventCellViewModel]
        combineEvents = { pair, pending in
            return pair.0 + pending + pair.1
        }
        
        return Publishers.CombineLatest(
            self.currentAndEventCellViewModels,
            self.subject.pendingTodoEvents
        )
        .map(combineEvents)
        .eraseToAnyPublisher()
    }
    
    var doneTodoFailed: AnyPublisher<String, Never> {
        return self.subject.doneFailedTodo
            .eraseToAnyPublisher()
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
