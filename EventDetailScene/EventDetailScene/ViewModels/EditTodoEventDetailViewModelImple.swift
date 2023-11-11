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
import Scenes


final class EditTodoEventDetailViewModelImple: EventDetailViewModel, @unchecked Sendable {
    
    private let todoId: String
    private let todoUsecase: any TodoEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    var router: (any EventDetailRouting)?
    
    init(
        todoId: String,
        todoUsecase: any TodoEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.todoId = todoId
        self.todoUsecase = todoUsecase
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
        case .remove(let onlyThisEvent): break
        case .copy: break
        case .addToTemplate: break
        case .share: break
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
            self?.editTodo(params |> \.repeatingUpdateScope .~ .onlyThisTime, addition)
        }
        let allConfirmed: () -> Void = { [weak self] in
            self?.editTodo(params |> \.repeatingUpdateScope .~ .all, addition)
        }
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("[TODO] edit todo scope".localized())
            |> \.message .~ pure("[TODO] select scope".localized())
            |> \.confirmText .~ "only this time".localized()
            |> \.confirmed .~ pure(onlyThisTimeConfirmed)
            |> \.withCancel .~ true
            |> \.cancelText .~ "all".localized()
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
                
                self?.router?.showToast("[TODO] todo saved".localized())
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
    }
}


extension EditTodoEventDetailViewModelImple {
    
    var isLoading: AnyPublisher<Bool, Never> {
        return self.subject.isLoading
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isTodo: AnyPublisher<Bool, Never> { Just(true).eraseToAnyPublisher() }
    
    var isTodoOrScheduleTogglable: Bool { false }
    
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
    
    var moreActions: AnyPublisher<[EventDetailMoreAction], Never> {
        let transform: (EventDetailBasicData) -> [EventDetailMoreAction] = { basic in
            let isRepeating = basic.selectedTime != nil && basic.eventRepeating != nil
            let removeActions: [EventDetailMoreAction] = isRepeating
                ? [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)]
                : [.remove(onlyThisEvent: false)]
            return removeActions + [.copy, .addToTemplate, .share]
        }
        return self.subject.basicData
            .compactMap { $0?.origin }
            .map(transform)
            .first()
            .eraseToAnyPublisher()
    }
}


extension EventDetailBasicData {
    
    init(todo: TodoEvent, _ timeZone: TimeZone) {
        self.name = todo.name
        self.selectedTime = todo.time.map { SelectedTime($0, timeZone) }
        self.eventRepeating = EventRepeatingTimeSelectResult.make(todo.time, todo.repeating, timeZone)
        self.eventTagId = todo.eventTagId ?? .default
    }
}

private extension EventRepeatingTimeSelectResult {
    
     static func make(_ eventTime: EventTime?, _ repeating: EventRepeating?, _ timeZone: TimeZone) -> Self? {
        guard let repeating,
              let start = eventTime.map ({ Date(timeIntervalSince1970: $0.lowerBoundWithFixed) }),
              let model = SelectRepeatingOptionModel(repeating.repeatOption, start, timeZone)
        else { return nil }
         return .init(text: model.text, repeating: repeating)
        
    }
}
