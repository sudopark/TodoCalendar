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
        let name = CurrentValueSubject<String?, Never>(nil)
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let isTodo = CurrentValueSubject<Bool, Never>(false)
        let selectedTime = CurrentValueSubject<SelectedTime?, Never>(nil)
        let repeatOptionSelectResult = CurrentValueSubject<EventRepeatingTimeSelectResult?, Never>(nil)
        let selectedTag = CurrentValueSubject<SelectedTag?, Never>(nil)
        let enteredMemo = CurrentValueSubject<String?, Never>(nil)
        let enteredLink = CurrentValueSubject<String?, Never>(nil)
        let selectedPlace = CurrentValueSubject<Place?, Never>(nil)
        let isSaving = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private var setupDefaultSelectTag: AnyCancellable?
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

extension AddEventViewModelImple: SelectEventRepeatOptionSceneListener, SelectEventTagSceneListener {
    
    func prepare() {
        
        self.subject.timeZone
            .compactMap { $0 }
            .first()
            .sink(receiveValue: { [weak self] timeZone in
                let now = Date(); let nextHour = now.addingTimeInterval(3600)
                self?.subject.selectedTime.send(
                    .period(
                        .init(now.timeIntervalSince1970, timeZone),
                        .init(nextHour.timeIntervalSince1970, timeZone)
                    )
                )
            })
            .store(in: &self.cancellables)
        
        self.setupDefaultSelectTag = self.eventTagUsease.latestUsedEventTag
            .map { tag -> SelectedTag in
                return tag.map { SelectedTag($0) } ?? .defaultTag
            }
            .first()
            .sink(receiveValue: { [weak self] tag in
                self?.subject.selectedTag.send(tag)
            })
    }
    
    func chooseMoreAction() {
        // do nothing
    }
    
    func close() {
        // TODO: show confirm close
    }
    
    func enter(name: String) {
        self.subject.name.send(name)
    }
    
    func toggleIsTodo() {
        self.subject.isTodo.send(!self.subject.isTodo.value)
    }
    
    func selectStartTime(_ date: Date) {
        guard let timeZone = self.subject.timeZone.value else { return }
        let timeText = SelectTimeText(date.timeIntervalSince1970, timeZone)
        
        let newTime: SelectedTime = switch self.subject.selectedTime.value {
            case .none, .at: .at(timeText)
            case .period(_, let end): .period(timeText, end)
            case .singleAllDay(let start) where start.date.isSameDay(date, at: timeZone):
                .singleAllDay(timeText |> \.time .~ nil)
            case .singleAllDay:
                .singleAllDay(timeText)
            case .alldayPeriod(_, let end): .alldayPeriod(timeText |> \.time .~ nil, end)
        }
        
        self.subject.selectedTime.send(newTime)
        self.syncEventRepeatingOptionStartTime(newTime, timeZone)
    }
    
    func selectEndtime(_ date: Date) {
        guard let timeZone = self.subject.timeZone.value else { return }
        let timeText = SelectTimeText(date.timeIntervalSince1970, timeZone)
        
        let newTime: SelectedTime? = switch self.subject.selectedTime.value {
            case .none: nil
            case .at(let start): .period(start, timeText)
            case .period(let start, _): .period(start, timeText)
            case .singleAllDay(let start) where start.date.isSameDay(date, at: timeZone): nil
            case .singleAllDay(let start): .alldayPeriod(start, timeText |> \.time .~ nil)
            case .alldayPeriod(let start, _): .alldayPeriod(start, timeText |> \.time .~ nil)
        }
        
        guard let newTime else { return }
        self.subject.selectedTime.send(newTime)
        self.syncEventRepeatingOptionStartTime(newTime, timeZone)
    }
    
    func removeTime() {
        self.subject.selectedTime.send(nil)
        self.subject.repeatOptionSelectResult.send(nil)
    }
    
    func removeEventEndTime() {
        guard let timeZone = self.subject.timeZone.value else { return }
        let newTime: SelectedTime? = switch self.subject.selectedTime.value {
        case .period(let start, _): .at(start)
        case .alldayPeriod(let start, _): .singleAllDay(start)
        default: nil
        }
        
        guard let newTime else { return }
        self.subject.selectedTime.send(newTime)
        self.syncEventRepeatingOptionStartTime(newTime, timeZone)
    }
    
    private func syncEventRepeatingOptionStartTime(
        _ selectedTime: SelectedTime, _ timeZone: TimeZone
    ) {
        guard let result = self.subject.repeatOptionSelectResult.value,
              let eventTime = selectedTime.eventTime(timeZone)
        else { return }
        
        let newOption = EventRepeating(
            repeatingStartTime: eventTime.lowerBoundWithFixed,
            repeatOption: result.repeating.repeatOption
        )
        |> \.repeatingEndTime .~ result.repeating.repeatingEndTime
        self.subject.repeatOptionSelectResult.send(
            .init(text: result.text, repeating: newOption)
        )
    }
    
    func toggleIsAllDay() {
        guard let timeZone = self.subject.timeZone.value,
              let time = self.subject.selectedTime.value?.toggleIsAllDay(timeZone)
        else { return }
        self.subject.selectedTime.send(time)
    }

    func selectRepeatOption() {

        guard let time = self.subject.selectedTime.value,
              let timeZone = self.subject.timeZone.value
        else { return }
        
        guard let eventTime = time.eventTime(timeZone)
        else {
            self.router?.showToast("[TODO] enter valid event time".localized())
            return
        }
        
        self.router?.routeToEventRepeatOptionSelect(
            startTime: Date(timeIntervalSince1970: eventTime.lowerBoundWithFixed),
            with: self.subject.repeatOptionSelectResult.value?.repeating,
            listener: self
        )
    }
    
    func selectEventRepeatOption(didSelect repeating: EventRepeatingTimeSelectResult) {
        self.subject.repeatOptionSelectResult.send(repeating)
    }
    
    func selectEventRepeatOptionNotRepeat() {
        self.subject.repeatOptionSelectResult.send(nil)
    }
    
    func selectEventTag() {
        self.setupDefaultSelectTag?.cancel()
        self.router?.routeToEventTagSelect(
            currentSelectedTagId: self.subject.selectedTag.value?.tagId ?? .default,
            listener: self
        )
    }
    
    func selectEventTag(didSelected tag: SelectedTag) {
        self.subject.selectedTag.send(tag)
    }
    
    func selectPlace() {
        // TODO: select place
    }
    
    func enter(url: String) {
        self.subject.enteredLink.send(url)
    }
    
    func enter(memo: String) {
        self.subject.enteredMemo.send(memo)
    }
    
    func save() {
        let isTodo = self.subject.isTodo.value
        isTodo ? self.saveNewTodoEvent() : self.saveNewScheduleEvent()
    }
    
    private func validEventTime() -> EventTime? {
        guard let timeZone = self.subject.timeZone.value,
              let time = self.subject.selectedTime.value
        else { return nil }
        return time.eventTime(timeZone)
    }
    
    private func saveNewTodoEvent() {
        guard let name = self.subject.name.value else { return }
        
        let eventTime = self.validEventTime()
        
        let params = TodoMakeParams()
            |> \.name .~ name
            |> \.eventTagId .~ self.subject.selectedTag.value?.tagId
            |> \.time .~ eventTime
            |> \.repeating .~ self.subject.repeatOptionSelectResult.value?.repeating
        
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
        guard let name = self.subject.name.value,
              let time = self.validEventTime()
        else { return }
        
        let params = ScheduleMakeParams()
            |> \.name .~ name
            |> \.time .~ pure(time)
            |> \.eventTagId .~ self.subject.selectedTag.value?.tagId
            |> \.repeating .~ self.subject.repeatOptionSelectResult.value?.repeating
        
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
        guard let eventId else { return }
        let detail = EventDetailData(eventId)
            |> \.memo .~ self.subject.enteredMemo.value
            |> \.url .~ self.subject.enteredLink.value
        let _ = try? await self.eventDetailDataUsecase.saveDetail(detail)
    }
}


// MARK: - AddEventViewModelImple Presenter

extension AddEventViewModelImple {
    
    var initialName: String? {
        // TOOD: todo quick 으로 진입한경우 해당값 전달
        nil
    }
 
    var isTodo: AnyPublisher<Bool, Never> {
        return self.subject.isTodo
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isTodoOrScheduleTogglable: Bool { true }
    
    var selectedTime: AnyPublisher<SelectedTime?, Never> {
        return self.subject.selectedTime
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var repeatOption: AnyPublisher<String?, Never> {
        return self.subject.repeatOptionSelectResult
            .map { $0?.text  }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedTag: AnyPublisher<SelectedTag, Never> {
        return self.subject.selectedTag
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedPlace: AnyPublisher<Place?, Never> {
        return self.subject.selectedPlace
            .eraseToAnyPublisher()
    }
    
    var isSavable: AnyPublisher<Bool, Never> {
        let transform: (Bool, String?, SelectedTime?) -> Bool = { isTodo, name, time in
            let nameIsNotEmpty = name?.isEmpty == false
            guard isTodo == false
            else {
                let timeSelectedButInvalid = time?.isValid != false
                return nameIsNotEmpty && timeSelectedButInvalid
            }
            let validtimeSelected = time?.isValid == true
            return nameIsNotEmpty && validtimeSelected
        }
        return Publishers.CombineLatest3(
            self.subject.isTodo,
            self.subject.name,
            self.subject.selectedTime
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
}
