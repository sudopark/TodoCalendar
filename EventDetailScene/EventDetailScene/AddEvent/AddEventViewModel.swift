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
    let date: Date
    
    init(_ timeStamp: TimeInterval, _ timeZone: TimeZone, withoutTime: Bool = false) {
        let date = Date(timeIntervalSince1970: timeStamp)
        let isSameYear = Date().components(timeZone).0 == date.components(timeZone).0
        self.year = isSameYear ? nil : date.yearText(at: timeZone)
        self.day = date.dateText(at: timeZone)
        self.time = withoutTime ? nil : date.timeText(at: timeZone)
        self.date = date
    }
    
    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.year == rhs.year && lhs.day == rhs.day && lhs.time == rhs.time
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
            ? .singleAllDay(.init(range.lowerBound, timeZone, withoutTime: true))
            : .alldayPeriod(.init(range.lowerBound, timeZone, withoutTime: true), .init(range.upperBound, timeZone, withoutTime: true))
        }
    }
    
    var isValid: Bool {
        switch self {
        case .period(let start, let end): return start.date < end.date
        case .alldayPeriod(let start, let end): return start.date < end.date
        default: return true
        }
    }
    
    fileprivate func eventTime(_ timeZone: TimeZone) -> EventTime? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let secondsFromGMT = timeZone.secondsFromGMT() |> TimeInterval.init
        switch self {
        case .at(let time):
            return .at(time.date.timeIntervalSince1970)
            
        case .period(let start, let end):
            guard start.date < end.date else { return nil }
            return .period(start.date.timeIntervalSince1970..<end.date.timeIntervalSince1970)
            
        case .singleAllDay(let time):
            guard let end = calendar.endOfDay(for: time.date) else { return nil }
            let start = calendar.startOfDay(for: time.date)
            return .allDay(
                start.timeIntervalSince1970..<end.timeIntervalSince1970,
                secondsFromGMT: secondsFromGMT
            )
        case .alldayPeriod(let start, let end):
            guard start.date < end.date, let endofEndDate = calendar.endOfDay(for: end.date)
            else { return nil }
            let startOfStarDate = calendar.startOfDay(for: start.date)
            return .allDay(
                startOfStarDate.timeIntervalSince1970..<endofEndDate.timeIntervalSince1970,
                secondsFromGMT: secondsFromGMT
            )
        }
    }
    
    fileprivate func toggleIsAllDay(_ timeZone: TimeZone) -> SelectedTime? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        switch self {
        case .at(let time):
            return .singleAllDay(.init(time.date.timeIntervalSince1970, timeZone, withoutTime: true))
        case .period(let start, let end) where start.date.isSameDay(end.date, at: timeZone):
            return .singleAllDay(.init(start.date.timeIntervalSince1970, timeZone, withoutTime: true))
        case .period(let start, let end):
            return .alldayPeriod(start |> \.time .~ nil, end |> \.time .~ nil)
        case .singleAllDay(let time):
            guard let end = calendar.endOfDay(for: time.date) else { return nil }
            let start = calendar.startOfDay(for: time.date)
            return .period(
                .init(start.timeIntervalSince1970, timeZone),
                .init(end.timeIntervalSince1970, timeZone)
            )
        case .alldayPeriod(let start, let end):
            return .period(
                .init(start.date.timeIntervalSince1970, timeZone),
                .init(end.date.timeIntervalSince1970, timeZone)
            )
        }
    }
}

protocol AddEventViewModel: AnyObject, Sendable, AddEventSceneInteractor {
    
    // interactor
    func prepare()
    func enter(name: String)
    func toggleIsTodo()
    func selectStartTime(_ date: Date)
    func selectEndtime(_ date: Date)
    func removeTime()
    func removeEventEndTime()
    func toggleIsAllDay()
    func selectRepeatOption()
    func selectEventTag()
    func selectPlace()
    func enter(url: String)
    func enter(memo: String)
    func save()
    
    // presenter
    var isTodo: AnyPublisher<Bool, Never> { get }
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

extension AddEventViewModelImple {
    
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
 
    var isTodo: AnyPublisher<Bool, Never> {
        return self.subject.isTodo
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedTime: AnyPublisher<SelectedTime?, Never> {
        return self.subject.selectedTime
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
