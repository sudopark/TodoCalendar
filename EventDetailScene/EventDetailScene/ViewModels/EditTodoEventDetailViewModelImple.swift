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


//final class EditTodoEventDetailViewModelImple: EventDetailViewModel, @unchecked Sendable {
//    
//    private let todoId: String
//    private let todoUsecase: any TodoEventUsecase
//    private let eventTagUsecase: any EventTagUsecase
//    private let eventDetailDataUsecase: any EventDetailDataUsecase
//    private let calendarSettingUsecase: any CalendarSettingUsecase
//    var router: (any EventDetailRouting)?
//    
//    init(
//        todoId: String,
//        todoUsecase: any TodoEventUsecase,
//        eventTagUsecase: any EventTagUsecase,
//        eventDetailDataUsecase: any EventDetailDataUsecase,
//        calendarSettingUsecase: any CalendarSettingUsecase
//    ) {
//        self.todoId = todoId
//        self.todoUsecase = todoUsecase
//        self.eventTagUsecase = eventTagUsecase
//        self.eventDetailDataUsecase = eventDetailDataUsecase
//        self.calendarSettingUsecase = calendarSettingUsecase
//    }
//    
//    private struct Subject {
//        let todo = CurrentValueSubject<TodoEvent?, Never>(nil)
//        let basicData = CurrentValueSubject<EventDetailBasicData?, Never>(nil)
//        let additionalData = CurrentValueSubject<OriginalAndCurrent<EventDetailData>?, Never>(nil)
//        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
//        let isSaving = CurrentValueSubject<Bool, Never>(false)
//        
//        func mutateBasicDataIfPossible(_ mutating: (EventDetailBasicData) -> EventDetailBasicData?) {
//            guard let old = self.basicData.value,
//                let newValue = mutating(old) else { return }
//            self.basicData.send(newValue)
//        }
//
//        func mutateAdditionalDataIfPossible(_ mutating: (OriginalAndCurrent<EventDetailData>) -> OriginalAndCurrent<EventDetailData>?) {
//            guard let old = self.additionalData.value,
//                  let newValue = mutating(old) else { return }
//            self.additionalData.send(newValue)
//        }
//    }
//    
//    private var cancellables: Set<AnyCancellable> = []
//    private let subject = Subject()
//    
//    private func internalBinding() {
//        
//        self.calendarSettingUsecase.currentTimeZone
//            .sink(receiveValue: { [weak self] timeZone in
//                self?.subject.timeZone.send(timeZone)
//            })
//            .store(in: &self.cancellables)
//    }
//}
//
//
//extension EditTodoEventDetailViewModelImple: SelectEventRepeatOptionSceneListener, SelectEventTagSceneListener {
//    
//    private func handleError() -> (Error) -> Void {
//        return { [weak self] error in
//            self?.router?.showError(error)
//        }
//    }
//    
//    func prepare() {
//        self.todoUsecase.todoEvent(self.todoId)
//            .sink(receiveValue: { [weak self] event in
//                self?.setupInitialTodoValue(event)
//            })
//            .store(in: &self.cancellables)
//        
//        self.eventDetailDataUsecase.loadDetail(self.todoId)
//            .sink(receiveValue: { [weak self] detail in
//                self?.subject.additionalData.send(.init(origin: detail))
//            })
//            .store(in: &self.cancellables)
//    }
//    
//    private func setupInitialTodoValue(_ todoEvent: TodoEvent) {
//        
//        let update: (TimeZone, SelectedTag) -> Void = { [weak self] timeZone, tag in
//            self?.subject.basicData.send(.init(todo: todoEvent, selectedTag: tag, timeZone))
//        }
//        
//        Publishers.CombineLatest(
//            self.subject.timeZone.compactMap { $0 },
//            self.eventTag(todoEvent)
//        )
//        .first()
//        .sink(receiveCompletion: { _ in }, receiveValue: update)
//        .store(in: &self.cancellables)
//    }
//    
//    private func eventTag(_ event: TodoEvent) -> AnyPublisher<SelectedTag, Never> {
//        switch event.eventTagId {
//        case .none, .default: return Just(SelectedTag.defaultTag).eraseToAnyPublisher()
//        case .holiday: return Just(SelectedTag.holiday).eraseToAnyPublisher()
//        case .custom(let id):
//            return self.eventTagUsecase.eventTag(id: id)
//                .map { SelectedTag($0) }
//                .eraseToAnyPublisher()
//        }
//    }
//    
//    func chooseMoreAction() {
//        // 이 이벤트만 삭제
//        // 이후 모든 이벤트 삭제
//        // 복사하기
//        // 템플릿에 추가
//        // 공유?
//    }
//    
//    func close() {
//        self.router?.showConfirmClose()
//    }
//    
//    func enter(name: String) {
//        self.subject.mutateBasicDataIfPossible {
//            $0 |> \.name .~ name
//        }
//    }
//    
//    func toggleIsTodo() {
//        // do nothing
//    }
//    
//    func selectStartTime(_ date: Date) {
//        guard let timeZone = self.subject.timeZone.value else { return }
//        self.subject.mutateBasicDataIfPossible {
//            return $0 
//                |> \.selectedTime %~ { $0.periodStartChanged(date, timeZone) }
//                |> \.eventRepeating %~ { $0?.updateRepeatStartTime(date.timeIntervalSince1970, timeZone) }
//        }
//    }
//    
//    func selectEndtime(_ date: Date) {
//        guard let timeZone = self.subject.timeZone.value else { return }
//        self.subject.mutateBasicDataIfPossible {
//            guard let newTime = $0.selectedTime.periodEndTimeChanged(date, timeZone)
//            else { return nil }
//            return $0 |> \.selectedTime .~ newTime
//        }
//    }
//    
//    func removeTime() {
//        self.subject.mutateBasicDataIfPossible {
//            return $0 
//                |> \.selectedTime .~ nil
//                |> \.eventRepeating .~ nil
//        }
//    }
//    
//    func removeEventEndTime() {
//        guard let timeZone = self.subject.timeZone.value else { return }
//        self.subject.mutateBasicDataIfPossible {
//            guard let newTime = $0.selectedTime.removePeriodEndTime(timeZone) else { return nil }
//            return $0 |> \.selectedTime .~ newTime
//        }
//    }
//    
//    func toggleIsAllDay() {
//        guard let timeZone = self.subject.timeZone.value else { return }
//        self.subject.mutateBasicDataIfPossible {
//            $0 |> \.selectedTime %~ { $0?.toggleIsAllDay(timeZone) }
//        }
//    }
//    
//    func selectRepeatOption() {
//        guard let time = self.subject.basicData.value?.selectedTime,
//              let timeZone = self.subject.timeZone.value
//        else { return }
//        
//        guard let eventTime = time.eventTime(timeZone)
//        else {
//            self.router?.showToast("[TODO] enter valid event time".localized())
//            return
//        }
//        
//        self.router?.routeToEventRepeatOptionSelect(
//            startTime: Date(timeIntervalSince1970: eventTime.lowerBoundWithFixed),
//            with: self.subject.basicData.value?.eventRepeating,
//            listener: self
//        )
//    }
//    
//    func selectEventRepeatOption(didSelect repeating: EventRepeatingTimeSelectResult) {
//        self.subject.mutateBasicDataIfPossible {
//            $0 |> \.eventRepeating .~ repeating
//        }
//    }
//    
//    func selectEventRepeatOptionNotRepeat() {
//        self.subject.mutateBasicDataIfPossible {
//            $0 |> \.eventRepeating .~ nil
//        }
//    }
//    
//    func selectEventTag() {
//        guard let tag = self.subject.basicData.value?.eventTag else { return }
//        self.router?.routeToEventTagSelect(
//            currentSelectedTagId: tag.tagId,
//            listener: self
//        )
//    }
//    
//    func selectEventTag(didSelected tag: SelectedTag) {
//        self.subject.mutateBasicDataIfPossible {
//            $0 |> \.eventTag .~ tag
//        }
//    }
//    
//    func selectPlace() {
//        // TOOD: select place
//    }
//    
//    func enter(url: String) {
//        self.subject.mutateAdditionalDataIfPossible {
//            $0 |> \.current %~ { $0 |> \.url .~ url }
//        }
//    }
//    
//    func enter(memo: String) {
//        self.subject.mutateAdditionalDataIfPossible {
//            $0 |> \.current %~ { $0 |> \.memo .~ memo }
//        }
//    }
//    
//    func save() {
//        // TOOD: save todo
//    }
//}
//
//
//extension EditTodoEventDetailViewModelImple {
//    
//    var isLoading: AnyPublisher<Bool, Never> {
//        let transform: (EventDetailBasicData?, OriginalAndCurrent<EventDetailData>?) -> Bool = { basic, additional in
//            return basic == nil || additional == nil
//        }
//        return Publishers.CombineLatest(
//            self.subject.basicData, self.subject.additionalData
//        )
//        .map(transform)
//        .removeDuplicates()
//        .eraseToAnyPublisher()
//    }
//    
//    var initialName: AnyPublisher<String?, Never> {
//        return self.subject.todo
//            .compactMap { $0?.name }
//            .eraseToAnyPublisher()
//    }
//    
//    var isTodo: AnyPublisher<Bool, Never> { Just(true).eraseToAnyPublisher() }
//    
//    var isTodoOrScheduleTogglable: Bool { false }
//    
//    var selectedTime: AnyPublisher<SelectedTime?, Never> {
//        return self.subject.basicData
//            .compactMap { $0 }
//            .map { $0.selectedTime }
//            .eraseToAnyPublisher()
//    }
//    
//    var repeatOption: AnyPublisher<String?, Never> {
//        Empty().eraseToAnyPublisher()
//    }
//    
//    var selectedTag: AnyPublisher<SelectedTag, Never> {
//        Empty().eraseToAnyPublisher()
//    }
//    
//    var selectedPlace: AnyPublisher<Place?, Never> {
//        Empty().eraseToAnyPublisher()
//    }
//    
//    var isSavable: AnyPublisher<Bool, Never> {
//        Empty().eraseToAnyPublisher()
//    }
//    
//    var isSaving: AnyPublisher<Bool, Never> {
//        Empty().eraseToAnyPublisher()
//    }
//}
//
//
//extension EventDetailBasicData {
//    
//    init(todo: TodoEvent, selectedTag: SelectedTag, _ timeZone: TimeZone) {
//        self.name = todo.name
//        self.selectedTime = todo.time.map { SelectedTime($0, timeZone) }
//        self.eventRepeating = EventRepeatingTimeSelectResult.make(todo.time, todo.repeating, timeZone)
//        self.eventTag = selectedTag
//    }
//}
//
//private extension EventRepeatingTimeSelectResult {
//    
//     static func make(_ eventTime: EventTime?, _ repeating: EventRepeating?, _ timeZone: TimeZone) -> Self? {
//        guard let repeating,
//              let start = eventTime.map ({ Date(timeIntervalSince1970: $0.lowerBoundWithFixed) }),
//              let model = SelectRepeatingOptionModel(repeating.repeatOption, start, timeZone)
//        else { return nil }
//         return .init(text: model.text, repeating: repeating)
//        
//    }
//}
