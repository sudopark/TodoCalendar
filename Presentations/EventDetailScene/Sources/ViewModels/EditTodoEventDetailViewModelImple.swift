//
//  EditTodoEventDetailViewModelImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/1/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes


final class EditTodoEventDetailViewModelImple: EventDetailViewModel, @unchecked Sendable {
    
    private let todoId: String
    private let todoUsecase: any TodoEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    var router: (any EventDetailRouting)?
    
    init(
        todoId: String,
        todoUsecase: any TodoEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        foremostEventUsecase: any ForemostEventUsecase
    ) {
        self.todoId = todoId
        self.todoUsecase = todoUsecase
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


extension EditTodoEventDetailViewModelImple: EventDetailInputListener {
    
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
        
        let handleComplete: (Subscribers.Completion<Error>) -> Void = { [weak self] completed in
            self?.subject.isLoading.send(false)
            if case .failure(let error) = completed {
                self?.handleError()(error)
            }
        }
        
        Publishers.CombineLatest(
            self.prepareBasicData(),
            self.additionDataWithoutError().mapNever()
        )
        .sink(receiveCompletion: handleComplete, receiveValue: handlePrepared)
        .store(in: &self.cancellables)
    }
    
    private func prepareBasicData() -> AnyPublisher<EventDetailBasicData, any Error> {
        let transform: (TodoEvent, TimeZone) -> EventDetailBasicData = { todo, timeZone in
            return EventDetailBasicData(todo: todo, timeZone)
        }
        return Publishers.CombineLatest(
            self.todoUsecase.todoEvent(self.todoId).removeDuplicates(),
            self.subject.timeZone.compactMap { $0 }.mapNever().first()
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
    
    private func additionDataWithoutError() -> AnyPublisher<EventDetailData, Never> {
        let id = self.todoId
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
        let message = onlyThisTime
            ? R.String.calendarEventMoreActionRemoveOnlyThistimeMessage
            : R.String.calendarEventMoreActionRemoveMessage
        let info = ConfirmDialogInfo()
            |> \.message .~ pure(message)
            |> \.confirmText .~ R.String.Common.remove
            |> \.confirmed .~ pure(self.removeTodo(onlyThistime: onlyThisTime))
            |> \.withCancel .~ true
            |> \.cancelText .~ R.String.Common.cancel
        self.router?.showConfirm(dialog: info)
    }
    
    private func removeTodo(onlyThistime: Bool) -> () -> Void {
        let todoId = self.todoId
        return { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    try await self?.todoUsecase.removeTodo(todoId, onlyThisTime: onlyThistime)
                    self?.router?.showToast("eventDetail.todoEvent_removed::message".localized())
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
        let todoId = self.todoId
        return { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    if toForemost {
                        try await self?.foremostEventUsecase.update(foremost: .init(todoId, true))
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
              let timeZone = self.subject.timeZone.value
        else { return }
        
        guard basic.isChanged || addition.isChanged
        else {
            self.router?.closeScene(animate: true, nil)
            return
        }
        
        let orinalTodoIsRepeating = basic.origin.eventRepeating != nil
        let params = self.todoEditParams(from: basic.current, timeZone)
        
        orinalTodoIsRepeating
            ? self.saveAfterShowConfirm(params, addition.current)
            : self.editTodo(params, addition.current)
    }
    
    private func saveAfterShowConfirm(
        _ params: TodoEditParams,
        _ addition: EventDetailData
    ) {
        
        let onlyThisTimeConfirmed: () -> Void = { [weak self] in
            self?.editTodo(
                params 
                    |> \.repeatingUpdateScope .~ .onlyThisTime
                    |> \.repeating .~ nil,
                addition
            )
        }
        let allConfirmed: () -> Void = { [weak self] in
            self?.editTodo(params |> \.repeatingUpdateScope .~ .all, addition)
        }
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("eventDetail.edit::repeating::confirm::ttile".localized())
            |> \.message .~ pure("eventDetail.edit::repeating::confirm::message".localized())
            |> \.confirmText .~ "eventDetail.edit::repeating::confirm::onlyThisTime::button".localized()
            |> \.confirmed .~ pure(onlyThisTimeConfirmed)
            |> \.withCancel .~ true
            |> \.cancelText .~ "eventDetail.edit::repeating::confirm::all::button".localized()
            |> \.canceled .~ pure(allConfirmed)
        self.router?.showConfirm(dialog: info)
    }
    
    private func editTodo(
        _ params: TodoEditParams,
        _ addition: EventDetailData
    ) {
        
        let todoId = self.todoId
        self.subject.isSaving.send(true)
        Task { [weak self] in
            
            do {
                let _ = try await self?.todoUsecase.updateTodoEvent(todoId, params)
                let _ = try? await self?.eventDetailDataUsecase.saveDetail(addition)
                
                self?.router?.showToast("eventDetail.todoEvent_saved::message".localized())
                self?.router?.closeScene(animate: true, nil)
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isSaving.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func todoEditParams(from basic: EventDetailBasicData, _ timeZone: TimeZone) -> TodoEditParams {
        return TodoEditParams()
            |> \.name .~ basic.name
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.time .~ basic.selectedTime?.eventTime(timeZone)
            |> \.repeating .~ basic.eventRepeating?.repeating
            |> \.notificationOptions .~ pure(basic.eventNotifications)
    }
}


extension EditTodoEventDetailViewModelImple {
    
    var isForemost: AnyPublisher<Bool, Never> {
        let todoId = self.todoId
        return self.foremostEventUsecase.foremostEvent
            .map { $0?.eventId == todoId }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        return self.subject.isLoading
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var eventDetailTypeModel: AnyPublisher<EventDetailTypeModel, Never> {
        return Just(EventDetailTypeModel.todoCase())
            .eraseToAnyPublisher()
    }
    
    var isSavable: AnyPublisher<Bool, Never> {
        
        let transform: (EventDetailBasicData?) -> Bool = { basic in
            let nameIsNotEmpty = basic?.name?.isEmpty == false
            let notInvalidTimeSelected = basic?.selectedTime?.isValid != false
            return nameIsNotEmpty && notInvalidTimeSelected
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
        let todoId = self.todoId
        let transform: (EventDetailBasicData, (any ForemostMarkableEvent)?) -> [[EventDetailMoreAction]] = { basic, foremostEvent in
            let isRepeating = basic.selectedTime != nil && basic.eventRepeating != nil
            let isForemost = foremostEvent?.eventId == todoId
            let removeActions: [EventDetailMoreAction] = isRepeating
                ? [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)]
                : [.remove(onlyThisEvent: false)]
            // TODO: share 기능 일단 비활성화
//            return [removeActions, [.toggleTo(isForemost: !isForemost), .share]]
            return [removeActions, [.toggleTo(isForemost: !isForemost)]]
        }
        return Publishers.CombineLatest(
            self.subject.basicData.compactMap{ $0?.origin },
            self.foremostEventUsecase.foremostEvent
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}


extension EventDetailBasicData {
    
    init(todo: TodoEvent, _ timeZone: TimeZone) {
        self.name = todo.name
        self.selectedTime = todo.time.map { SelectedTime($0, timeZone) }
        self.eventRepeating = EventRepeatingTimeSelectResult.make(todo.time, todo.repeating, timeZone)
        self.eventTagId = todo.eventTagId ?? .default
        self.eventNotifications = todo.notificationOptions
        self.excludeTimes = []
    }
}

extension EventRepeatingTimeSelectResult {
    
     static func make(_ eventTime: EventTime?, _ repeating: EventRepeating?, _ timeZone: TimeZone) -> Self? {
        guard let repeating,
              let start = eventTime.map ({ Date(timeIntervalSince1970: $0.lowerBoundWithFixed) }),
              let model = SelectRepeatingOptionModel(repeating.repeatOption, start, timeZone)
        else { return nil }
         return .init(text: model.text, repeating: repeating)
        
    }
}
