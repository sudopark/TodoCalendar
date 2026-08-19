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

        self.holidayName = currentModel.holidays.isEmpty
            ? nil
            : currentModel.holidays.map { $0.name }.joined(separator: "\n")
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
    func showSharePreview()
    func refreshUncompletedTodoEvents()
    func enterVoiceInput()
    func finishVoiceInput()

    func enterKeyboardInput()
    func enterImageInput()
    func stopAIAgentInput()
    func submitAIAgent(_ text: String)
    func handleAIEntryButtonTap()
    func showAIGuide()
    func attachListener(_ listener: any DayEventListSceneListener)

    // presenter
    var isAIAgentEnabled: Bool { get }
    var foremostEventModel: AnyPublisher<(any EventCellViewModel)?, Never> { get }
    var uncompletedTodoEventModels: AnyPublisher<[TodoEventCellViewModel], Never> { get }
    var selectedDay: AnyPublisher<SelectedDayModel, Never> { get }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> { get }
    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> { get }
    var aiAgentState: AnyPublisher<AIAgentState, Never> { get }
    var recognizingText: AnyPublisher<String, Never> { get }
    var voiceLevel: AnyPublisher<Float, Never> { get }
}


// MARK: - DayEventListViewModelImple

final class DayEventListViewModelImple: DayEventListViewModel, @unchecked Sendable {

    private let calendarUsecase: any CalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let eventListUsecase: any CalendarEventListhUsecase
    private let todoEventUsecase: any TodoEventUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let uiSettingUsecase: any UISettingUsecase
    private let accountUsecase: any AccountUsecase
    private let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    private let eventLiveActivityUsecase: any EventLiveActivityUsecase
    var router: (any DayEventListRouting)?
    private weak var listener: (any DayEventListSceneListener)?

    init(
        calendarUsecase: any CalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventListUsecase: any CalendarEventListhUsecase,
        todoEventUsecase: any TodoEventUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        uiSettingUsecase: any UISettingUsecase,
        accountUsecase: any AccountUsecase,
        aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase,
        eventLiveActivityUsecase: any EventLiveActivityUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.eventListUsecase = eventListUsecase
        self.todoEventUsecase = todoEventUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.accountUsecase = accountUsecase
        self.aiAgentOrchestrationUsecase = aiAgentOrchestrationUsecase
        self.eventLiveActivityUsecase = eventLiveActivityUsecase

        self.internalBind()
    }


    private struct CurrentDayAndEventLists {
        let currentDay: CurrentSelectDayModel
        let events: [any CalendarEvent]
    }

    private struct Subject {
        let currentDayAndEventLists = CurrentValueSubject<CurrentDayAndEventLists?, Never>(nil)
        let tagMaps = CurrentValueSubject<[String: any EventTag], Never>([:])
        let pendingTodoEvents = CurrentValueSubject<[PendingTodoEventCellViewModel], Never>([])
        let isSignedIn = CurrentValueSubject<Bool, Never>(false)
        let aiAgentState = CurrentValueSubject<AIAgentState?, Never>(nil)
    }

    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    private let cvmCombineScheduler = DispatchQueue(label: "serial-combine")

    private func internalBind() {
        self.accountUsecase.currentAccountInfo
            .map { $0 != nil }
            .sink { [weak self] signedIn in
                self?.subject.isSignedIn.send(signedIn)
            }
            .store(in: &self.cancellables)

        self.aiAgentOrchestrationUsecase.state
            .sink { [weak self] state in
                self?.subject.aiAgentState.send(state)
            }
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
        let params = MakeEventParams(
            selectedDate: selectDate, makeSource: .todo(withName: givenName)
        )
        self.router?.routeToMakeNewEvent(params)
    }

    func makeEvent() {
        guard let selectDate = self.currentDate else { return }
        let params = MakeEventParams(selectedDate: selectDate, makeSource: .schedule())
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

    func showSharePreview() {
        guard let range = self.subject.currentDayAndEventLists.value?.currentDay.range
        else { return }
        self.router?.showSharePreview(range: range)
    }

    func refreshUncompletedTodoEvents() {
        self.todoEventUsecase.refreshUncompletedTodos()
    }

    func enterVoiceInput() {
        guard self.subject.isSignedIn.value else {
            self.confirmSignInForAIAgent()
            return
        }
        self.aiAgentOrchestrationUsecase.enterVoiceInput()
    }

    func finishVoiceInput() {
        self.aiAgentOrchestrationUsecase.finishVoiceInput()
    }

    func enterKeyboardInput() {
        self.aiAgentOrchestrationUsecase.enterKeyboardInput()
        guard !self.aiAgentOrchestrationUsecase.isCreditExhausted else { return }
        self.router?.routeToAIKeyboardInput()
    }

    func enterImageInput() {
        self.aiAgentOrchestrationUsecase.enterImageInput()
        guard !self.aiAgentOrchestrationUsecase.isCreditExhausted else { return }
        self.router?.routeToImageSourceSelect { [weak self] in
            self?.aiAgentOrchestrationUsecase.enterVoiceInput()
        }
    }

    func stopAIAgentInput() {
        self.aiAgentOrchestrationUsecase.stopInput()
    }

    func submitAIAgent(_ text: String) {
        do {
            try self.aiAgentOrchestrationUsecase.submit(text)
        } catch {
            self.router?.showError(error)
        }
    }

    func attachListener(_ listener: any DayEventListSceneListener) {
        self.listener = listener
    }

    func handleAIEntryButtonTap() {
        let state = self.subject.aiAgentState.value ?? .idle
        if Self.isCommandPhase(state) {
            self.listener?.dayEventListDidRequestShowAICommand()
        } else {
            self.enterVoiceInput()
        }
    }

    func showAIGuide() {
        self.router?.routeToAIGuide()
    }

    private static func isCommandPhase(_ state: AIAgentState) -> Bool {
        switch state {
        case .processing, .confirm, .done, .failed: return true
        case .idle, .listening: return false
        }
    }

    private func confirmSignInForAIAgent() {
        let info = ConfirmDialogInfo.aiAgentNeedSignIn { [weak self] in
            self?.router?.routeToSignIn()
        }
        self.router?.showConfirm(dialog: info)
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
                    calendarEvent, in: todayRange, timeZone, is24Form,
                    forceShowEventDateDurationText: true
                )

            case let schedule as ScheduleEvent:
                let calendarEvent = ScheduleCalendarEvent.events(
                    from: schedule, in: timeZone,
                    foremostId: schedule.uuid
                ).first
                return calendarEvent.flatMap { event in
                    return ScheduleEventCellViewModel(
                        event, in: todayRange, timeZone: timeZone, is24Form,
                        forceShowEventDateDurationText: true
                    )
                }
            default: return nil
            }
        }
        let applyRegistration: ((any EventCellViewModel)?, LiveActivityTarget?) -> (any EventCellViewModel)?
        applyRegistration = { cvm, target in
            cvm?.liveActivityRegistrationApplied(target)
        }

        let foremostModel = Publishers.CombineLatest4(
            self.foremostEventUsecase.foremostEvent,
            self.calendarUsecase.currentDay.removeDuplicates(),
            self.calendarSettingUsecase.currentTimeZone,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }.removeDuplicates()
        )
        .map(asCellViewModel)

        return Publishers.CombineLatest(foremostModel, self.eventLiveActivityUsecase.registeredTarget)
            .map(applyRegistration)
            .removeDuplicates(by: { $0?.customCompareKey == $1?.customCompareKey })
            .eraseToAnyPublisher()
    }

    var uncompletedTodoEventModels: AnyPublisher<[TodoEventCellViewModel], Never> {
        let asCellViewModels: (
            [TodoCalendarEvent], CalendarComponent.Day, TimeZone, Bool
        ) -> [TodoEventCellViewModel]?
        asCellViewModels = { todos, today, timeZone, is24Form in
            guard let todayRange = today.dayRange(timeZone) else { return nil }
            return todos
                .filter { !$0.isForemost }
                .compactMap {
                    TodoEventCellViewModel($0, in: todayRange, timeZone, is24Form, forceShowEventDateDurationText: true)
                        .map { $0 |> \.isUncompletedTodo .~ true }
                }
        }
        let applyRegistration: ([TodoEventCellViewModel], LiveActivityTarget?) -> [TodoEventCellViewModel]
        applyRegistration = { todos, target in
            todos.compactMap { $0.liveActivityRegistrationApplied(target) as? TodoEventCellViewModel }
        }

        let todos = Publishers.CombineLatest4(
            self.eventListUsecase.uncompletedTodos(),
            self.calendarUsecase.currentDay,
            self.calendarSettingUsecase.currentTimeZone,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }.removeDuplicates()
        )
        .compactMap(asCellViewModels)

        return Publishers.CombineLatest(todos, self.eventLiveActivityUsecase.registeredTarget)
            .map(applyRegistration)
            .removeDuplicates(by: { $0.map { $0.customCompareKey } == $1.map { $0.customCompareKey } })
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

        let combineEvents: (CurrentAndEvents, [PendingTodoEventCellViewModel]) -> [any EventCellViewModel]
        combineEvents = { pair, pending in
            return pair.0 + pending + pair.1
        }
        let applyRegistration: ([any EventCellViewModel], LiveActivityTarget?) -> [any EventCellViewModel]
        applyRegistration = { cvms, target in
            cvms.map { $0.liveActivityRegistrationApplied(target) }
        }

        let cells = Publishers.CombineLatest(
            self.currentAndEventCellViewModels.receive(on: self.cvmCombineScheduler),
            self.subject.pendingTodoEvents.receive(on: self.cvmCombineScheduler)
        )
        .map(combineEvents)

        return Publishers.CombineLatest(cells, self.eventLiveActivityUsecase.registeredTarget)
            .map(applyRegistration)
            .removeDuplicates(by: { $0.map { $0.customCompareKey } == $1.map { $0.customCompareKey } })
            .eraseToAnyPublisher()
    }

    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> {
        return self.foremostEventUsecase.foremostEventMarkingStatus
    }

    var isAIAgentEnabled: Bool {
        return FeatureFlag.isEnable(.aiAgent)
    }

    var aiAgentState: AnyPublisher<AIAgentState, Never> {
        return self.aiAgentOrchestrationUsecase.state
    }

    var recognizingText: AnyPublisher<String, Never> {
        return self.aiAgentOrchestrationUsecase.recognizingText
    }

    var voiceLevel: AnyPublisher<Float, Never> {
        return self.aiAgentOrchestrationUsecase.voiceLevel
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

            let mapper = EventCellViewModelMapper(range: range, timeZone: timeZone, is24hourForm: is24HourForm)
            let eventCellsWithTime = mapper.cellViewModels(
                from: dayAndEvents.events.sortedByEventTime()
            )

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
            self.eventListUsecase.currentTodoEvents(),
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }.removeDuplicates()
        )
        .map(asCellViewModel)
        .map(filterForemost)
        .eraseToAnyPublisher()
    }
}


// MARK: - private helpers

private extension EventCellViewModel {

    func liveActivityRegistrationApplied(_ registered: LiveActivityTarget?) -> any EventCellViewModel {
        switch self {
        case let todo as TodoEventCellViewModel:
            return todo |> \.isLiveActivityRegistered .~ (registered != nil && todo.liveActivityTarget == registered)
        case let schedule as ScheduleEventCellViewModel:
            return schedule |> \.isLiveActivityRegistered .~ (registered != nil && schedule.liveActivityTarget == registered)
        case let holiday as HolidayEventCellViewModel:
            return holiday |> \.isLiveActivityRegistered .~ (registered != nil && holiday.liveActivityTarget == registered)
        default:
            return self
        }
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
