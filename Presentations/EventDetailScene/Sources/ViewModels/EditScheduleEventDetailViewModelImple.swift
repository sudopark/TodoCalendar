//
//  EditScheduleEventDetailViewModelImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/12/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


final class EditScheduleEventDetailViewModelImple: EventDetailViewModel, @unchecked Sendable {
    
    private let scheduleId: String
    private let scheduleUsecase: any ScheduleEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    var router: (any EventDetailRouting)?
    
    init(
        scheduleId: String,
        scheduleUsecase: any ScheduleEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.scheduleId = scheduleId
        self.scheduleUsecase = scheduleUsecase
        self.eventTagUsecase = eventTagUsecase
        self.eventDetailDataUsecase = eventDetailDataUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        
        self.internalBinding()
    }
    
    private struct Subject {
        typealias Basic = OriginalAndCurrent<EventDetailBasicData>
        typealias Addition = OriginalAndCurrent<EventDetailData>
        let basicData = CurrentValueSubject<Basic?, Never>(nil)
        let additionalData = CurrentValueSubject<Addition?, Never>(nil)
        let isLoading = CurrentValueSubject<Bool, Never>(false)
        let isSaving = CurrentValueSubject<Bool, Never>(false)
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    private weak var inputInteractor: (any EventDetailInputInteractor)?
    
    private func internalBinding() {
        
        self.calendarSettingUsecase.currentTimeZone
            .sink(receiveValue: { [weak self] timeZone in
                self?.subject.timeZone.send(timeZone)
            })
            .store(in: &self.cancellables)
    }
}

extension EditScheduleEventDetailViewModelImple: EventDetailInputListener {
    
    private func handleError() -> (Error) -> Void {
        return { [weak self] error in
            self?.router?.showError(error)
        }
    }
    
    func attachInput() {
        self.inputInteractor = self.router?.attachInput(self)
    }
    
    func prepare() {
        
        self.subject.isLoading.send(true)
        
        let handlePrepared: (EventDetailBasicData, EventDetailData) -> Void = { [weak self] basic, addition in
            self?.subject.basicData.send(
                .init(origin: basic)
            )
            self?.subject.additionalData.send(
                .init(origin: addition)
            )
            self?.inputInteractor?.prepared(basic: basic, additional: addition)
        }
        let handleCompleted: (Subscribers.Completion<Error>) -> Void = { [weak self] completed in
            self?.subject.isLoading.send(false)
            if case .failure(let error) = completed {
                self?.handleError()(error)
            }
        }
        
        Publishers.CombineLatest(
            self.prepareBasicData(),
            self.additionDataWithoutError().mapNever()
        )
        .sink(receiveCompletion: handleCompleted, receiveValue: handlePrepared)
        .store(in: &self.cancellables)
    }
    
    private func prepareBasicData() -> AnyPublisher<EventDetailBasicData, any Error> {
        let transform: (ScheduleEvent, TimeZone) -> EventDetailBasicData = { schedule, timeZone in
            return EventDetailBasicData(schedule, timeZone)
        }
        return Publishers.CombineLatest(
            self.scheduleUsecase.scheduleEvent(self.scheduleId).removeDuplicates(),
            self.subject.timeZone.compactMap { $0 }.mapNever().first()
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
    
    private func additionDataWithoutError() -> AnyPublisher<EventDetailData, Never> {
        let id = self.scheduleId
        return self.eventDetailDataUsecase.loadDetail(id)
            .catch { _ in Just(.init(id)) }
            .eraseToAnyPublisher()
    }
    
    func handleMoreAction(_ action: EventDetailMoreAction) {
        switch action {
        case .remove(let onlyThisEvent):
            self.removeEventAfterConfirm(onlyThisTime: onlyThisEvent)
            
        case .copy:
            // TODO:
            break
        case .addToTemplate:
            // TODO:
            break
        case .share:
            // TODO:
            break
        }
    }
    
    private func removeEventAfterConfirm(onlyThisTime: Bool) {
        guard let timeZone = self.subject.timeZone.value,
              let time = self.subject.basicData.value?.origin.selectedTime?.eventTime(timeZone)
        else { return }
        let onlyThisTime = onlyThisTime ? time : nil
        let info = ConfirmDialogInfo()
            |> \.message .~ pure("do you want to remove this event".localized())
            |> \.confirmText .~ "remove".localized()
            |> \.confirmed .~ pure(self.removeSchedule(onlyThisTime))
            |> \.withCancel .~ true
            |> \.cancelText .~ "cancel".localized()
        self.router?.showConfirm(dialog: info)
    }
    
    private func removeSchedule(_ onlyThistime: EventTime?) -> () -> Void {
        let scheduleId = self.scheduleId
        return { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    try await self?.scheduleUsecase.removeScheduleEvent(
                        scheduleId, onlyThisTime: onlyThistime
                    )
                    self?.router?.showToast("schedule removed".localized())
                    self?.router?.closeScene()
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }
    
    func close() {
        self.router?.showConfirmClose()
    }
    
    // do nothing
    func toggleIsTodo() { }
    
    func eventDetail(didInput basic: EventDetailBasicData, additional: EventDetailData) {
        
        guard let oldBasic = self.subject.basicData.value,
              let oldAddition = self.subject.additionalData.value
        else { return }
        
        self.subject.basicData.send(
            oldBasic |> \.current .~ basic
        )
        self.subject.additionalData.send(
            oldAddition |> \.current .~ additional
        )
    }
    
    func save() {
        guard let basic = self.subject.basicData.value,
              let addition = self.subject.additionalData.value,
              let timeZone = self.subject.timeZone.value,
              let originEventTime = basic.origin.selectedTime?.eventTime(timeZone)
        else { return }
        
        guard basic.isChanged || addition.isChanged
        else {
            self.router?.closeScene()
            return
        }
        
        let originalScheduleIsRepeating = basic.origin.eventRepeating != nil
        let params = self.scheduleEditParams(from: basic.current, timeZone)
        
        originalScheduleIsRepeating
            ? saveAfterShowConfirm(originEventTime, params, addition.current)
            : editSchedule(params, addition.current)
    }
    
    private func saveAfterShowConfirm(
        _ originEventTime: EventTime,
        _ params: ScheduleEditParams,
        _ addition: EventDetailData
    ) {
        
        let onlyThisTimeConfirmed: () -> Void = { [weak self] in
            self?.editSchedule(
                params |> \.repeatingUpdateScope .~ .onlyThisTime(originEventTime),
                addition
            )
        }
        let allConfirmed: () -> Void = { [weak self] in
            self?.editSchedule(params |> \.repeatingUpdateScope .~ .all, addition)
        }
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("[TODO] edit schedule scope".localized())
            |> \.message .~ pure("[TODO] select scope".localized())
            |> \.confirmText .~ "only this time".localized()
            |> \.confirmed .~ pure(onlyThisTimeConfirmed)
            |> \.withCancel .~ true
            |> \.cancelText .~ "all".localized()
            |> \.canceled .~ pure(allConfirmed)
        self.router?.showConfirm(dialog: info)
    }
    
    private func editSchedule(
        _ params: ScheduleEditParams,
        _ addition: EventDetailData
    ) {
        
        let scheduleId = self.scheduleId
        self.subject.isSaving.send(true)
        Task { [weak self] in
            
            do {
                let _ = try await self?.scheduleUsecase.updateScheduleEvent(scheduleId, params)
                let _ = try? await self?.eventDetailDataUsecase.saveDetail(addition)
                
                self?.router?.showToast("[TODO] schedule saved".localized())
                self?.router?.closeScene(animate: true, nil)
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isSaving.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func scheduleEditParams(from basic: EventDetailBasicData, _ timeZone: TimeZone) -> ScheduleEditParams {
        
        return ScheduleEditParams()
            |> \.name .~ basic.name
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.time .~ basic.selectedTime?.eventTime(timeZone)
            |> \.repeating .~ basic.eventRepeating?.repeating
            |> \.notificationOptions .~ pure(basic.eventNotifications)
        
    }
}

extension EditScheduleEventDetailViewModelImple {
    
    var isLoading: AnyPublisher<Bool, Never> {
        return self.subject.isLoading
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var eventDetailTypeModel: AnyPublisher<EventDetailTypeModel, Never> {
        return Just(EventDetailTypeModel.scheduleCase())
            .eraseToAnyPublisher()
    }
    
    var isSavable: AnyPublisher<Bool, Never> {
        let transform: (EventDetailBasicData?) -> Bool = { basic in
            let nameIsNotEmpty = basic?.name?.isEmpty == false
            let validTimeSelected = basic?.selectedTime?.isValid == true
            return nameIsNotEmpty && validTimeSelected
        }
        
        return self.subject.basicData
            .map { $0?.current }
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
        let transform: (EventDetailBasicData) -> [[EventDetailMoreAction]] = { basic in
            let isRepeating = basic.selectedTime != nil && basic.eventRepeating != nil
            let removeActions: [EventDetailMoreAction] = isRepeating
                ? [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)]
                : [.remove(onlyThisEvent: false)]
            return [removeActions, [.copy, .addToTemplate, .share]]
        }
        return self.subject.basicData
            .compactMap { $0?.origin }
            .map(transform)
            .first()
            .eraseToAnyPublisher()
    }
}

private extension EventDetailBasicData {
    
    init(_ schedule: ScheduleEvent, _ timeZone: TimeZone) {
        self.name = schedule.name
        self.selectedTime = SelectedTime(schedule.time, timeZone)
        self.eventRepeating = EventRepeatingTimeSelectResult.make(schedule.time, schedule.repeating, timeZone)
        self.eventTagId = schedule.eventTagId ?? .default
        self.eventNotifications = schedule.notificationOptions
    }
}
