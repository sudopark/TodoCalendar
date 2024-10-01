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
        formatter.dateFormat = "date_form::yyyy_MM_dd_E_".localized()
        self.dateText = formatter.string(from: date)
        
        let lunarFormatter = DateFormatter() 
            |> \.timeZone .~ timeZone
            |> \.calendar .~ Calendar(identifier: .chinese)
        
        lunarFormatter.dateFormat = "date_form::MM_dd".localized()
        self.lunarDateText = "🌕 \(lunarFormatter.string(from: date))"
        
        self.holidayName = currentModel.holiday?.localName
    }
}

// MARK: - DayEventListViewModel

protocol DayEventListViewModel: AnyObject, Sendable, DayEventListSceneInteractor {

    // interactor
    func addNewTodoQuickly(withName: String)
    func makeTodoEvent(with givenName: String)
    func makeEvent()
    func makeEventByTemplate()
    func showDoneTodoList()
    
    // presenter
    var foremostEventModel: AnyPublisher<(any EventCellViewModel)?, Never> { get }
    var selectedDay: AnyPublisher<SelectedDayModel, Never> { get }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> { get }
}


// MARK: - DayEventListViewModelImple

final class DayEventListViewModelImple: DayEventListViewModel, @unchecked Sendable {
    
    private let calendarUsecase: any CalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let todoEventUsecase: any TodoEventUsecase
    private let scheduleEventUsecase: any ScheduleEventUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any DayEventListRouting)?
    
    init(
        calendarUsecase: any CalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.foremostEventUsecase = foremostEventUsecase
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
        let pendingTodoEvents = CurrentValueSubject<[PendingTodoEventCellViewModel], Never>([])
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    private let cvmCombineScheduler = DispatchQueue(label: "serial-combine")
    
    private func internalBind() {
        
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
    
    func showDoneTodoList() {
        self.router?.showDoneTodoList()
    }
}


// MARK: - DayEventListViewModelImple Presenter

extension DayEventListViewModelImple {
    
    var foremostEventModel: AnyPublisher<
        (any EventCellViewModel)?, Never
    > {
        
        let asCellViewModel: (
            (any ForemostMarkableEvent)?, CalendarComponent.Day, TimeZone, Bool
        ) -> (any EventCellViewModel)?
        asCellViewModel = { event, today, timeZone, is24Form in
            guard let todayRange = today.dayRange(timeZone)
            else { return nil }
            
            switch event {
            case let todo as TodoEvent:
                let calendarEvent = TodoCalendarEvent(todo, in: timeZone, isForemost: true)
                return TodoEventCellViewModel(
                    calendarEvent, in: todayRange, timeZone, is24Form
                )
                
            case let schedule as ScheduleEvent:
                let calendarEvent = ScheduleCalendarEvent.events(
                    from: schedule, in: timeZone
                ).first
                return calendarEvent.flatMap { event in
                    return ScheduleEventCellViewModel(
                        event, in: todayRange, timeZone: timeZone, is24Form
                    )
                }
            default: return nil
            }
        }
        let foremostModel = Publishers.CombineLatest4(
            self.foremostEventUsecase.foremostEvent,
            self.calendarUsecase.currentDay,
            self.calendarSettingUsecase.currentTimeZone,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }.removeDuplicates()
        )
        .map(asCellViewModel)
        
        let applyTag: ((any EventCellViewModel)?) -> AnyPublisher<(any EventCellViewModel)?, Never>
        applyTag = { [weak self] model in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            guard let tagId = model?.tagId.customTagId else { return Just(model).eraseToAnyPublisher() }
            return self.eventTagUsecase.eventTag(id: tagId)
                .map { tag -> (any EventCellViewModel)? in
                    var model = model
                    model?.applyTagColor(tag)
                    return model
                }
                .eraseToAnyPublisher()
        }
        
        return foremostModel
        .map(applyTag)
        .switchToLatest()
        .removeDuplicates(by: { $0?.customCompareKey == $1?.customCompareKey })
        .eraseToAnyPublisher()
    }
    
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
        
        return self.eventTagUsecase.cellWithTagInfo(self.cellViewModelsFromEvent)
        .filterTagActivated(self.eventTagUsecase) { $0.tagId }
        .removeDuplicates(by: { $0.map { $0.customCompareKey } == $1.map { $0.customCompareKey } })
        .eraseToAnyPublisher()
    }
    
    private typealias CurrentAndEvents = ([any EventCellViewModel], [any EventCellViewModel])
    
    private var currentAndEventCellViewModels: AnyPublisher<CurrentAndEvents, Never> {
        let asCellViewModel: (
            CurrentDayAndEventLists, TimeZone, [TodoCalendarEvent], Bool
        ) -> CurrentAndEvents
        asCellViewModel = { dayAndEvents, timeZone, currentTodos, is24HourForm in
            
            let range = dayAndEvents.currentDay.range
            let currentTodoCells = currentTodos
                .sortedByCreateTime()
                .compactMap { TodoEventCellViewModel($0, in: range, timeZone, is24HourForm) }
            
            let eventCellsWithTime = dayAndEvents.events
                .sortedByEventTime()
                .compactMap { event -> (any EventCellViewModel)? in
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
        
        let filterForemost: (CurrentAndEvents) -> CurrentAndEvents = { pair in
            return (
                pair.0.filter { !$0.isForemost },
                pair.1.filter { !$0.isForemost }
            )
        }
        
        return Publishers.CombineLatest4(
            self.subject.currentDayAndEventLists.compactMap { $0 },
            self.calendarSettingUsecase.currentTimeZone,
            self.currentTodoEvents,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }.removeDuplicates()
        )
        .map(asCellViewModel)
        .map(filterForemost)
        .eraseToAnyPublisher()
    }
    
    private var currentTodoEvents: AnyPublisher<[TodoCalendarEvent], Never> {
        let transform: ([TodoEvent], (any ForemostMarkableEvent)?) -> [TodoCalendarEvent]
        transform = { todos, foremost in
            return todos.map {
                TodoCalendarEvent(current: $0, isForemost: foremost?.eventId == $0.uuid)
            }
        }
        return Publishers.CombineLatest(
            self.todoEventUsecase.currentTodoEvents,
            self.foremostEventUsecase.foremostEvent
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
    
    private var cellViewModelsFromEvent: AnyPublisher<[any EventCellViewModel], Never> {
        
        let combineEvents: (CurrentAndEvents, [PendingTodoEventCellViewModel]) -> [any EventCellViewModel]
        combineEvents = { pair, pending in
            return pair.0 + pending + pair.1
        }
        
        return Publishers.CombineLatest(
            self.currentAndEventCellViewModels.receive(on: self.cvmCombineScheduler),
            self.subject.pendingTodoEvents.receive(on: self.cvmCombineScheduler)
        )
        .map(combineEvents)
        .eraseToAnyPublisher()
    }
}

private extension EventTime {
    
    func durationText(_ timeZone: TimeZone) -> String? {
        
        switch self {
        case .period(let range):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = R.String.dateFormMMMDHHMm
            return "\(range.rangeText(formatter))(\(range.totalPeriodText()))"
            
        case .allDay(let range, let secondsFrom):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = R.String.dateFormMMMD
            let shifttingRange = range.shiftting(secondsFrom, to: timeZone)
            let days = Int(shifttingRange.upperBound-shifttingRange.lowerBound) / (24 * 3600)
            let totalPeriodText = days > 0 ? R.String.calendarEventTimePeriodSomeDays(days+1) : nil
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
            return R.String.calendarEventTimePeriodSomeMinutes(m)
        case let (d, h, _) where d == 0:
            return R.String.calendarEventTimePeriodSomeHours(h)
        case let (d, h, _):
            return R.String.calendarEventTimePeriodSomeDaysSomeHours(d, h)
        }
    }
}
