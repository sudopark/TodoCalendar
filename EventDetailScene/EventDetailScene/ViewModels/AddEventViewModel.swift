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
import Scenes


// MARK: - AddEventViewModelImple

final class AddEventViewModelImple: EventDetailViewModel, @unchecked Sendable {
    
    private let todoUsecase: any TodoEventUsecase
    private let scheduleUsecase: any ScheduleEventUsecase
    private let eventTagUsease: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    var router: (any EventDetailRouting)?
    
    init(
        isTodo: Bool,
        todoUsecase: any TodoEventUsecase,
        scheduleUsecase: any ScheduleEventUsecase,
        eventTagUsease: any EventTagUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase
    ) {
        
        self.todoUsecase = todoUsecase
        self.scheduleUsecase = scheduleUsecase
        self.eventTagUsease = eventTagUsease
        self.calendarSettingUsecase = calendarSettingUsecase
        self.eventDetailDataUsecase = eventDetailDataUsecase
        
        self.internalBinding()
        self.subject.isTodo.send(isTodo)
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
        
        let defaultSelectTime = self.subject.timeZone.compactMap { $0 }
            .first()
            .map { timeZone in
                let now = Date(); let nextHour = now.addingTimeInterval(3600)
                return SelectedTime.period(
                    .init(now.timeIntervalSince1970, timeZone),
                    .init(nextHour.timeIntervalSince1970, timeZone)
                )
            }
        let defaultTag = self.eventTagUsease.latestUsedEventTag
            .first()
            .map { $0?.uuid }
        
        Publishers.CombineLatest(defaultSelectTime, defaultTag)
            .sink(receiveValue: { [weak self] (time, id) in
                // TOOD: send to input viewModel
                let initailData = EventDetailBasicData(
                    name: nil,
                    eventTagId: id.map {.custom($0) } ?? .default
                )
                    |> \.selectedTime .~ time
                self?.inputInteractor?.prepared(
                    basic: initailData, additional: .init("pending")
                )
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
            |> \.name .~ name
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.time .~ eventTime
            |> \.repeating .~ basic.eventRepeating?.repeating
        
        self.subject.isSaving.send(true)
        
        Task { [weak self] in
            do {
                let newTodo = try await self?.todoUsecase.makeTodoEvent(params)
                await self?.saveEventDetailWithoutError(newTodo?.uuid)
                
                self?.router?.showToast("[TODO] todo saved".localized())
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
            |> \.name .~ name
            |> \.time .~ pure(time)
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.repeating .~ basic.eventRepeating?.repeating
        
        self.subject.isSaving.send(true)
        
        Task { [weak self] in
            do {
                let newSchedule = try await self?.scheduleUsecase.makeScheduleEvent(params)
                await self?.saveEventDetailWithoutError(newSchedule?.uuid)
                
                self?.router?.showToast("[TODO] schedule saved".localized())
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
    
    var isTodo: AnyPublisher<Bool, Never> {
        return self.subject.isTodo
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isTodoOrScheduleTogglable: Bool { true }
    
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
        return Just([
            [.copy, .addToTemplate]
        ])
        .eraseToAnyPublisher()
    }
}
