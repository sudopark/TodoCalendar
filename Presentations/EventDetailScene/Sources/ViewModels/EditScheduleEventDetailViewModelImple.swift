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
import Extensions
import Scenes


final class EditScheduleEventDetailViewModelImple: EventDetailViewModel, @unchecked Sendable {
    
    private let scheduleId: String
    private let repeatingEventTargetTime: EventTime?
    private let scheduleUsecase: any ScheduleEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    var router: (any EventDetailRouting)?
    weak var listener: EventDetailSceneListener?
    
    init(
        scheduleId: String,
        repeatingEventTargetTime: EventTime?,
        scheduleUsecase: any ScheduleEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        foremostEventUsecase: any ForemostEventUsecase
    ) {
        self.scheduleId = scheduleId
        self.repeatingEventTargetTime = repeatingEventTargetTime
        self.scheduleUsecase = scheduleUsecase
        self.eventTagUsecase = eventTagUsecase
        self.eventDetailDataUsecase = eventDetailDataUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.foremostEventUsecase = foremostEventUsecase
        
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
        let targetTime = self.repeatingEventTargetTime
        let transform: (ScheduleEvent, TimeZone) -> EventDetailBasicData = { schedule, timeZone in
            return EventDetailBasicData(schedule, targetTime, timeZone)
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
            
        case .toggleTo(let isForemost):
            self.toggleForemostAfterConfirm(toForemost: isForemost)
            
        case .copy:
            self.copyEvent()
            
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
        let message = onlyThisTime
            ? R.String.calendarEventMoreActionRemoveOnlyThistimeMessage
            : R.String.calendarEventMoreActionRemoveMessage
        let onlyThisTime = onlyThisTime ? time : nil
        let info = ConfirmDialogInfo()
            |> \.message .~ pure(message)
            |> \.confirmText .~ R.String.Common.remove
            |> \.confirmed .~ pure(self.removeSchedule(onlyThisTime))
            |> \.withCancel .~ true
            |> \.cancelText .~ R.String.Common.cancel
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
                    self?.router?.showToast(R.String.EventDetail.scheduleEventRemovedMessage)
                    self?.router?.closeScene()
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }
    
    private func toggleForemostAfterConfirm(toForemost: Bool) {
        
        let message = toForemost
            ? R.String.calendarEventMoreActionMarkAsForemost
            : R.String.calendarEventMoreActionUnmarkAsForemost
        let info = ConfirmDialogInfo()
            |> \.title .~ R.String.calendarEventMoreActionForemostEventTitle
            |> \.message .~ pure(message)
            |> \.confirmText .~ R.String.Common.confirm
            |> \.confirmed .~ pure(self.toggleFormost(toForemost))
            |> \.withCancel .~ true
            |> \.cancelText .~ R.String.Common.cancel
        self.router?.showConfirm(dialog: info)
    }
    
    private func toggleFormost(_ toForemost: Bool) -> () -> Void {
        let scheduleId = self.scheduleId
        return { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    if toForemost {
                        try await self?.foremostEventUsecase.update(foremost: .init(scheduleId, false))
                    } else {
                        try await self?.foremostEventUsecase.remove()
                    }
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }
    
    private func copyEvent() {
        guard let basic = self.subject.basicData.value?.current,
              let timeZone = self.subject.timeZone.value
        else { return }
        
        let params = ScheduleMakeParams(basic, timeZone)
        let additional = self.subject.additionalData.value?.current
        self.router?.closeScene(animate: true) { [weak self] in
            self?.listener?.eventDetail(copyFromSchedule: params, detail: additional)
        }
    }
    
    func close() {
        self.router?.showConfirmClose()
    }
    
    // do nothing
    func toggleIsTodo() { }
    
    func showTodoGuide() { }
    
    func showForemostEventGuide() {
        self.router?.showForemostEventGuide()
    }
    
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
              let timeZone = self.subject.timeZone.value
        else { return }
        
        guard basic.isChanged || addition.isChanged
        else {
            self.router?.closeScene()
            return
        }
        
        let originalScheduleIsRepeating = basic.origin.eventRepeating != nil
        let params = self.scheduleEditParams(from: basic.current, timeZone)
        
        originalScheduleIsRepeating
            ? saveAfterShowConfirmEditRepeatingEvent(timeZone, params, addition.current)
            : editSchedule(params, addition.current)
    }
    
    private func saveAfterShowConfirmEditRepeatingEvent(
        _ timeZone: TimeZone,
        _ params: SchedulePutParams,
        _ addition: EventDetailData
    ) {
        
        let basic = self.subject.basicData.value
        let userSelectTime = basic?.userSelectedTime(timeZone)
        
        var form = ActionSheetForm()
            |> \.title .~ pure("eventDetail.edit::repeating::confirm::ttile".localized())
            |> \.message .~ pure("eventDetail.edit::repeating::confirm::message".localized())
        
        // 모두 수정
        if let originEventTime = basic?.origin.originEventTime {
            let allAction = ActionSheetForm.Action("eventDetail.edit::repeating::confirm::all::button".localized()) { [weak self] in
                self?.editSchedule(
                    params
                        |> \.repeatingUpdateScope .~ .all
                        |> \.time .~ (userSelectTime ?? originEventTime),
                    addition
                )
            }
            form.actions.append(allAction)
        }
        
        if let repeatingTargetTime = self.repeatingEventTargetTime {
            // 이번부터 수정
            let fromNowAction = ActionSheetForm.Action("eventDetail.edit::repeating::confirm::fromNow::button".localized()) { [weak self] in
                self?.editSchedule(
                    params |> \.repeatingUpdateScope .~ .fromNow(repeatingTargetTime),
                    addition
                )
            }
            form.actions.append(fromNowAction)
            
            // 이번만 수정
            let onlyThisTimeAction = ActionSheetForm.Action("eventDetail.edit::repeating::confirm::onlyThisTime::button".localized()) { [weak self] in
                self?.editSchedule(
                    params
                        |> \.repeatingUpdateScope .~ .onlyThisTime(repeatingTargetTime)
                        |> \.repeating .~ nil,
                    addition
                )
            }
            form.actions.append(onlyThisTimeAction)
        }
        form.actions.append(.init("common.cancel".localized(), style: .cancel))
        
        self.router?.showActionSheet(form)
    }
    
    private func editSchedule(
        _ params: SchedulePutParams,
        _ addition: EventDetailData
    ) {
        
        let scheduleId = self.scheduleId
        self.subject.isSaving.send(true)
        Task { [weak self] in
            
            do {
                let _ = try await self?.scheduleUsecase.updateScheduleEvent(scheduleId, params)
                let _ = try? await self?.eventDetailDataUsecase.saveDetail(addition)
                
                self?.router?.showToast("eventDetail.scheduleEvent_saved::message".localized())
                self?.router?.closeScene(animate: true, nil)
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isSaving.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func scheduleEditParams(from basic: EventDetailBasicData, _ timeZone: TimeZone) -> SchedulePutParams {
        
        return SchedulePutParams()
            |> \.name .~ basic.name
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.time .~ basic.selectedTime?.eventTime(timeZone)
            |> \.repeating .~ basic.eventRepeating?.repeating
            |> \.notificationOptions .~ pure(basic.eventNotifications)
            |> \.repeatingTimeToExcludes .~ pure(Array(basic.excludeTimes))
        
    }
}

extension EditScheduleEventDetailViewModelImple {
    
    var isForemost: AnyPublisher<Bool, Never> {
        let scheduleId = self.scheduleId
        return self.foremostEventUsecase.foremostEvent
            .map { $0?.eventId == scheduleId }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
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
        let scheduleId = self.scheduleId
        let transform: (EventDetailBasicData, (any ForemostMarkableEvent)?) -> [[EventDetailMoreAction]] = { basic, foremostEvent in
            let isRepeating = basic.selectedTime != nil && basic.eventRepeating != nil
            let isForemost = foremostEvent?.eventId == scheduleId
            let removeActions: [EventDetailMoreAction] = isRepeating
                ? [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)]
                : [.remove(onlyThisEvent: false)]
            // TODO: share 기능 일단 비활성화
            let otherActions: [EventDetailMoreAction] = isRepeating
//                ? [.share]
//                : [.toggleTo(isForemost: !isForemost), .share]
                ? [.copy]
                : [.toggleTo(isForemost: !isForemost), .copy]
            return [removeActions, otherActions]
        }
        return Publishers.CombineLatest(
            self.subject.basicData.compactMap { $0?.origin },
            self.foremostEventUsecase.foremostEvent
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}

private extension EventDetailBasicData {
    
    init(
        _ schedule: ScheduleEvent,
        _ repeatingEventTargetTime: EventTime?,
        _ timeZone: TimeZone
    ) {
        self.name = schedule.name
        self.originEventTime = schedule.time
        self.selectedTime = SelectedTime(
            repeatingEventTargetTime ?? schedule.time, timeZone
        )
        self.eventRepeating = EventRepeatingTimeSelectResult.make(schedule.time, schedule.repeating, timeZone)
        self.eventTagId = schedule.eventTagId ?? .default
        self.eventNotifications = schedule.notificationOptions
        self.excludeTimes = schedule.repeatingTimeToExcludes
    }
}

private extension OriginalAndCurrent where T == EventDetailBasicData {
    
    func userSelectedTime(_ timeZone: TimeZone) -> EventTime? {
        let isUserSelected = self.origin.selectedTime != self.current.selectedTime
        return isUserSelected ? self.current.selectedTime?.eventTime(timeZone) : nil
    }
}

private extension ScheduleMakeParams {
    
    init(_ basic: EventDetailBasicData, _ timeZone: TimeZone) {
        self.init()
        self.name = basic.name
        self.time = basic.selectedTime?.eventTime(timeZone)
        self.eventTagId = basic.eventTagId
        self.repeating = basic.eventRepeating?.repeating
        self.notificationOptions = basic.eventNotifications
    }
}
