//
//  
//  AddEventViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes


// MARK: - AddEventViewModelImple

final class AddEventViewModelImple: EventDetailViewModel, @unchecked Sendable {
    
    private let initailMakeParams: MakeEventParams
    private let todoUsecase: any TodoEventUsecase
    private let scheduleUsecase: any ScheduleEventUsecase
    private let eventTagUsease: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    private let eventSettingUsecase: any EventSettingUsecase
    private let eventNotificationSettingUsecase: any EventNotificationSettingUsecase
    var router: (any EventDetailRouting)?
    
    init(
        params: MakeEventParams,
        todoUsecase: any TodoEventUsecase,
        scheduleUsecase: any ScheduleEventUsecase,
        eventTagUsease: any EventTagUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase,
        eventSettingUsecase: any EventSettingUsecase,
        eventNotificationSettingUsecase: any EventNotificationSettingUsecase
    ) {
        
        self.initailMakeParams = params
        self.todoUsecase = todoUsecase
        self.scheduleUsecase = scheduleUsecase
        self.eventTagUsease = eventTagUsease
        self.calendarSettingUsecase = calendarSettingUsecase
        self.eventDetailDataUsecase = eventDetailDataUsecase
        self.eventSettingUsecase = eventSettingUsecase
        self.eventNotificationSettingUsecase = eventNotificationSettingUsecase
        
        self.internalBinding()
    }
    
    
    private struct Subject {
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let isTodo = CurrentValueSubject<Bool, Never>(false)
        let basic = CurrentValueSubject<EventDetailBasicData?, Never>(nil)
        let additional = CurrentValueSubject<EventDetailData?, Never>(nil)
        let isSaving = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private var inputInteractor: (any EventDetailInputInteractor)?
    private let subject = Subject()
    
    private func internalBinding() {
        self.calendarSettingUsecase.currentTimeZone
            .sink(receiveValue: { [weak self] timeZone in
                self?.subject.timeZone.send(timeZone)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - AddEventViewModelImple Interactor

extension AddEventViewModelImple: EventDetailInputListener {
    
    func attachInput() {
        self.inputInteractor = self.router?.attachInput(self)
    }
    
    func eventDetail(didInput basic: EventDetailBasicData, additional: EventDetailData) {
        self.subject.basic.send(basic)
        self.subject.additional.send(additional)
    }
    
    func prepare() {
        
        let params = self.initailMakeParams
        let defaultSetting = self.eventSettingUsecase.loadEventSetting()
        
        let defaultSelectTime = self.subject.timeZone.compactMap { $0 }
            .first()
            .compactMap { timeZone in
                return params.selectedDate.selectDateDefaultTime(
                    timeZone,
                    defaultPeriod: defaultSetting.defaultNewEventPeriod
                )
            }

        let defaultTag = self.eventSettingUsecase.loadEventSetting().defaultNewEventTagId
        
        let defaultNotification = self.eventNotificationSettingUsecase
            .loadDefailtNotificationTimeOption(forAllDay: false)
        
        defaultSelectTime
            .sink(receiveValue: { [weak self] time in
                let initailData = EventDetailBasicData(
                    name: params.initialTodoInfo?.name,
                    eventTagId: defaultTag
                )
                |> \.selectedTime .~ time
                |> \.eventNotifications .~ (defaultNotification.map { [$0] } ?? [])
                self?.inputInteractor?.prepared(
                    basic: initailData, additional: .init("pending")
                )
                self?.subject.isTodo.send(params.initialTodoInfo != nil)
            })
            .store(in: &self.cancellables)
    }
    
    func handleMoreAction(_ action: EventDetailMoreAction) {
        switch action {
        case .copy:
            // TODO:
            break
        case .addToTemplate:
            // TODO: break
            break
        default: break
        }
    }
    
    func close() {
        self.router?.showConfirmClose()
    }
    
    func toggleIsTodo() {
        self.subject.isTodo.send(!self.subject.isTodo.value)
    }
    
    
    func save() {
        let isTodo = self.subject.isTodo.value
        isTodo ? self.saveNewTodoEvent() : self.saveNewScheduleEvent()
    }
    
    private func validEventTime(_ basic: EventDetailBasicData) -> EventTime? {
        guard let timeZone = self.subject.timeZone.value,
              let time = basic.selectedTime
        else { return nil }
        return time.eventTime(timeZone)
    }
    
    private func saveNewTodoEvent() {
        guard let basic = self.subject.basic.value, let name = basic.name
        else { return }
        
        let eventTime = self.validEventTime(basic)
        
        let params = TodoMakeParams()
            |> \.name .~ pure(name)
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.time .~ eventTime
            |> \.repeating .~ basic.eventRepeating?.repeating
            |> \.notificationOptions .~ pure(basic.eventNotifications)
        
        self.subject.isSaving.send(true)
        
        Task { [weak self] in
            do {
                let newTodo = try await self?.todoUsecase.makeTodoEvent(params)
                await self?.saveEventDetailWithoutError(newTodo?.uuid)
                
                self?.router?.showToast(R.String.EventDetail.addNewTodoMessage)
                self?.router?.closeScene(animate: true, nil)
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isSaving.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func saveNewScheduleEvent() {
        guard let basic = self.subject.basic.value,
              let name = basic.name, let time = self.validEventTime(basic)
        else { return }
        
        let params = ScheduleMakeParams()
            |> \.name .~ pure(name)
            |> \.time .~ pure(time)
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.repeating .~ basic.eventRepeating?.repeating
            |> \.notificationOptions .~ pure(basic.eventNotifications)
        
        self.subject.isSaving.send(true)
        
        Task { [weak self] in
            do {
                let newSchedule = try await self?.scheduleUsecase.makeScheduleEvent(params)
                await self?.saveEventDetailWithoutError(newSchedule?.uuid)
                
                self?.router?.showToast(R.String.EventDetail.addNewScheduleMessage)
                self?.router?.closeScene(animate: true, nil)
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isSaving.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func saveEventDetailWithoutError(_ eventId: String?) async {
        guard let eventId, let addition = self.subject.additional.value
        else { return }
        let detail = EventDetailData(eventId)
            |> \.memo .~ addition.memo
            |> \.url .~ addition.url
        let _ = try? await self.eventDetailDataUsecase.saveDetail(detail)
    }
}


// MARK: - AddEventViewModelImple Presenter

extension AddEventViewModelImple {
    
    var isForemost: AnyPublisher<Bool, Never> {
        return Just(false).eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        let transform: (EventDetailBasicData?, EventDetailData?) -> Bool = { basic, addition in
            return basic == nil || addition == nil
        }
        return Publishers.CombineLatest(
            self.subject.basic, self.subject.additional
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var eventDetailTypeModel: AnyPublisher<EventDetailTypeModel, Never> {
        return self.subject.isTodo
            .map { EventDetailTypeModel.makeCase($0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isSavable: AnyPublisher<Bool, Never> {
        let transform: (Bool, EventDetailBasicData?) -> Bool = { isTodo, basic in
            let nameIsNotEmpty = basic?.name?.isEmpty == false
            guard isTodo == false
            else {
                let notInvalidTimeSelected = basic?.selectedTime?.isValid != false
                return nameIsNotEmpty && notInvalidTimeSelected
            }
            let validtimeSelected = basic?.selectedTime?.isValid == true
            return nameIsNotEmpty && validtimeSelected
        }
        return Publishers.CombineLatest(
            self.subject.isTodo,
            self.subject.basic
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var isSaving: AnyPublisher<Bool, Never> {
        return self.subject.isSaving
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var moreActions: AnyPublisher<[[EventDetailMoreAction]], Never> {
        return Empty().eraseToAnyPublisher()
        // TODO: 일단 비활성화
//        return Just([
//            [.copy, .addToTemplate]
//        ])
//        .eraseToAnyPublisher()
    }
}

private extension Date {
    
    func selectDateDefaultTime(
        _ timeZone: TimeZone,
        defaultPeriod: EventSettings.DefaultNewEventPeriod
    ) -> SelectedTime? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let now = Date()
        guard let start = calendar.dateBySetting(from: now, mutating: {
            $0.year = calendar.component(.year, from: self)
            $0.month = calendar.component(.month, from: self)
            $0.day = calendar.component(.day, from: self)
        })
        else { return nil }
        
        func period(_ interval: TimeInterval) -> SelectedTime {
            let next = start.addingTimeInterval(interval)
            return .period(
                .init(start.timeIntervalSince1970, timeZone),
                .init(next.timeIntervalSince1970, timeZone)
            )
        }
        
        switch defaultPeriod {
        case .minute0: return .at(.init(start.timeIntervalSince1970, timeZone))
        case .minute5: return period(5 * 60)
        case .minute10: return period(10 * 60)
        case .minute15: return period(15 * 60)
        case .minute30: return period(30 * 60)
        case .minute45: return period(45 * 60)
        case .hour1: return period(60 * 60)
        case .hour2: return period(120 * 60)
        case .allDay: return .singleAllDay(.init(start.timeIntervalSince1970, timeZone, withoutTime: true))
        }
    }
}
