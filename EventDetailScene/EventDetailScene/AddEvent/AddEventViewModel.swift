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


// MARK: - AddEventViewModel

struct SelectTimeText: Equatable {
    var year: String?
    let day: String
    var time: String?
    
    init(_ timeStamp: TimeInterval, _ timeZone: TimeZone, withoutTime: Bool = false) {
        let date = Date(timeIntervalSince1970: timeStamp)
        let isSameYear = Date().components(timeZone).0 == date.components(timeZone).0
        self.year = isSameYear ? nil : date.yearText(at: timeZone)
        self.day = date.dateText(at: timeZone)
        self.time = withoutTime ? nil : date.timeText(at: timeZone)
    }
}

enum SelectedTime: Equatable {
    case at(SelectTimeText)
    case period(SelectTimeText, SelectTimeText)
    case singleAllDay(SelectTimeText)
    case alldayPeriod(SelectTimeText, SelectTimeText)
    
    init(_ time: EventTime, _ timeZone: TimeZone) {
        switch time {
        case .at(let timeStamp):
            self = .at(
                .init(timeStamp, timeZone)
            )
            
        case .period(let range):
            self = .period(
                .init(range.lowerBound, timeZone), .init(range.upperBound, timeZone)
            )
            
        case .allDay:
            let range = time.rangeWithShifttingifNeed(on: timeZone)
            let isSameDay = Date(timeIntervalSince1970: range.lowerBound)
                .isSameDay(Date(timeIntervalSince1970: range.upperBound), at: timeZone)
            self = isSameDay
            ? .singleAllDay(.init(range.lowerBound, timeZone))
            : .alldayPeriod(.init(range.lowerBound, timeZone), .init(range.upperBound, timeZone))
        }
    }
}

protocol AddEventViewModel: AnyObject, Sendable, AddEventSceneInteractor {
    
    // interactor
    func prepare()
    func enter(name: String)
    func toggleIsTodo()
    func eventTimeSelect(didSelect time: EventTime?)
    func toggleIsAllDay()
    func selectRepeatOption()
    func selectEventTag()
    func selectPlace()
    func enter(url: String)
    func enter(memo: String)
    func save()
    
    // presenter
    var isTodo: AnyPublisher<Bool, Never> { get }
    // TODO: 시간 선택 여부에 따라 업데이트되어야함
    var selectedTime: AnyPublisher<SelectedTime?, Never> { get }
    var repeatOption: AnyPublisher<String, Never> { get }
    var selectedTag: AnyPublisher<SelectedTag, Never> { get }
    var selectedPlace: AnyPublisher<Place?, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
}


// MARK: - AddEventViewModelImple

final class AddEventViewModelImple: AddEventViewModel, @unchecked Sendable {
    
    private let todoUsecase: any TodoEventUsecase
    private let scheduleUsecase: any ScheduleEventUsecase
    private let eventTagUsease: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    var router: (any AddEventRouting)?
    
    init(
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
    }
    
    
    private struct Subject {
        let name = CurrentValueSubject<String?, Never>(nil)
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let isTodo = CurrentValueSubject<Bool, Never>(false)
        let selectedTime = CurrentValueSubject<EventTime?, Never>(nil)
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

extension AddEventViewModelImple {
    
    func prepare() {
        
        let now = Date(); let nextHour = now.addingTimeInterval(3600)
        self.subject.selectedTime.send(
            .period(now.timeIntervalSince1970..<nextHour.timeIntervalSince1970)
        )
        
        self.setupDefaultSelectTag = self.eventTagUsease.latestUsedEventTag
            .map { tag -> SelectedTag in
                return tag.map { SelectedTag($0) } ?? .defaultTag
            }
            .first()
            .sink(receiveValue: { [weak self] tag in
                self?.subject.selectedTag.send(tag)
            })
    }
    
    func enter(name: String) {
        self.subject.name.send(name)
    }
    
    func toggleIsTodo() {
        self.subject.isTodo.send(!self.subject.isTodo.value)
    }
    
    func eventTimeSelect(didSelect time: EventTime?) {
        self.subject.selectedTime.send(time)
        guard let time = time 
        else {
            self.subject.repeatOptionSelectResult.send(nil)
            return
        }
        guard let result = self.subject.repeatOptionSelectResult.value else { return }
        
        let newOption = EventRepeating(
            repeatingStartTime: time.lowerBoundWithFixed,
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

        guard let time = self.subject.selectedTime.value else { return }
        
        self.router?.routeToEventRepeatOptionSelect(
            startTime: Date(timeIntervalSince1970: time.lowerBoundWithFixed),
            with: self.subject.repeatOptionSelectResult.value?.repeating
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
            currentSelectedTagId: self.subject.selectedTag.value?.tagId ?? .default
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
    
    private func saveNewTodoEvent() {
        guard let name = self.subject.name.value else { return }
        
        let params = TodoMakeParams()
            |> \.name .~ name
            |> \.eventTagId .~ self.subject.selectedTag.value?.tagId
            |> \.time .~ self.subject.selectedTime.value
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
              let time = self.subject.selectedTime.value
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
 
    var isTodo: AnyPublisher<Bool, Never> {
        return self.subject.isTodo
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedTime: AnyPublisher<SelectedTime?, Never> {
        let transform: (TimeZone, EventTime?) -> SelectedTime? = { timeZone, selected in
            return selected.map { SelectedTime($0, timeZone) }
        }
        return Publishers.CombineLatest(
            self.subject.timeZone.compactMap { $0 },
            self.subject.selectedTime
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var repeatOption: AnyPublisher<String, Never> {
        return self.subject.repeatOptionSelectResult
            .map { $0?.text ?? "not repeat".localized() }
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
        let transform: (Bool, String?, EventTime?) -> Bool = { isTodo, name, time in
            let nameIsNotEmpty = name?.isEmpty == false
            guard isTodo == false
            else {
                return nameIsNotEmpty
            }
            return nameIsNotEmpty && time != nil
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

extension Date {
    
    func yearText(at timeZone: TimeZone) -> String {
        let dateForm = DateFormatter()
        dateForm.timeZone = timeZone
        dateForm.dateFormat = "yyyy".localized()
        return dateForm.string(from: self)
    }
    
    func dateText(at timeZone: TimeZone) -> String {
        let dateForm = DateFormatter()
        dateForm.timeZone = timeZone
        dateForm.dateFormat = "MMM dd (E)".localized()
        return dateForm.string(from: self)
    }
    
    func timeText(at timeZone: TimeZone) -> String {
        let timeForm = DateFormatter()
        timeForm.timeZone = timeZone
        timeForm.dateFormat = "HH:00".localized()
        return timeForm.string(from: self)
    }
    
    func isSameDay(_ other: Date, at timeZone: TimeZone) -> Bool {
        let lhsCompos = self.components(timeZone)
        let rhsCompos = other.components(timeZone)
        return lhsCompos.0 == rhsCompos.0
            && lhsCompos.1 == rhsCompos.1
            && lhsCompos.2 == rhsCompos.2
    }
    
    func components(_ timeZone: TimeZone) -> (Int?, Int?, Int?) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let compos = calendar.dateComponents([.year, .month, .day], from: self)
        return (compos.year, compos.month, compos.day)
    }
}

private extension EventTime {
    
    func toggleIsAllDay(_ timeZone: TimeZone) -> EventTime? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let secondsFromGMT = TimeInterval(timeZone.secondsFromGMT())
        switch self {
        case .at(let time):
            let date = Date(timeIntervalSince1970: time)
            guard let end = calendar.endOfDay(for: date) else { return nil }
            let start = calendar.startOfDay(for: date)
            return .allDay(
                start.timeIntervalSince1970..<end.timeIntervalSince1970,
                secondsFromGMT: secondsFromGMT
            )
            
        case .period(let range):
            let (startDate, endDate) = (
                Date(timeIntervalSince1970: range.lowerBound),
                Date(timeIntervalSince1970: range.upperBound)
            )
            guard let endDayOfEnd = calendar.endOfDay(for: endDate) else { return nil }
            let startOfStart = calendar.startOfDay(for: startDate)
            return .allDay(
                startOfStart.timeIntervalSince1970..<endDayOfEnd.timeIntervalSince1970,
                secondsFromGMT: secondsFromGMT
            )
            
        case .allDay(let range, secondsFromGMT: _):
            return .period(range)
        }
    }
}
