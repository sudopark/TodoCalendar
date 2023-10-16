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

enum SelectedTime: Equatable {
    case at(dateText: String, timeText: String)
    case period(_ startDate: String, _ startTime: String, _ endDate: String, _ endTime: String)
    case alldayPeriod(_ start: String, _ end: String?)
    
    init(_ time: EventTime, _ timeZone: TimeZone) {
        switch time {
        case .at(let timeStamp):
            let time = Date(timeIntervalSince1970: timeStamp)
            self = .at(
                dateText: time.dateText(at: timeZone), timeText: time.timeText(at: timeZone)
            )
            
        case .period(let range):
            let start = Date(timeIntervalSince1970: range.lowerBound)
            let end = Date(timeIntervalSince1970: range.upperBound)
            self = .period(
                start.dateText(at: timeZone), start.timeText(at: timeZone),
                end.dateText(at: timeZone), end.timeText(at: timeZone)
            )
        case .allDay(let range, _):
            let start = Date(timeIntervalSince1970: range.lowerBound)
            let end = Date(timeIntervalSince1970: range.upperBound)
            let isSameDay = start.isSameDay(end, at: timeZone)
            self = .alldayPeriod(
                start.dateText(at: timeZone),
                isSameDay ? nil : end.dateText(at: timeZone)
            )
        }
    }
}

struct SelectPlace: Equatable {
    let name: String
    let coordinate: String
}

struct SelectedTag: Equatable {
    let tagId: AllEventTagId
    let name: String
    let color: EventTagColor
    
    init(
        _ tagId: AllEventTagId,
        _ name: String,
        _ color: EventTagColor
    ) {
        self.tagId = tagId
        self.name = name
        self.color = color
    }
    
    init(_ tag: EventTag) {
        self.tagId = .custom(tag.uuid)
        self.name = tag.name
        self.color = .custom(hex: tag.colorHex)
    }
    
    static var defaultTag: SelectedTag {
        return .init(.default, "default".localized(), .default)
    }
}

protocol AddEventViewModel: AnyObject, Sendable, AddEventSceneInteractor {
    
    // interactor
    func enter(name: String)
    func toggleIsTodo()
    func selectTime()
    func toggleIsAllDay()
    func selectRepeatOption()
    func selectEventTag()
    func selectPlace()
    func enter(url: String)
    func enter(memo: String)
    func showMoreAction()
    func save()
    
    // presenter
    var isTodo: AnyPublisher<Bool, Never> { get }
    var selectedTime: AnyPublisher<SelectedTime, Never> { get }
    var repeatOption: AnyPublisher<String, Never> { get }
    var selectedTag: AnyPublisher<SelectedTag, Never> { get }
    var selectedPlace: AnyPublisher<SelectPlace?, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
}


// MARK: - AddEventViewModelImple

final class AddEventViewModelImple: AddEventViewModel, @unchecked Sendable {
    
    private let todoUsecase: any TodoEventUsecase
    private let scheduleUsecase: any ScheduleEventUsecase
    private let eventTagUsease: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    var router: (any AddEventRouting)?
    
    init(
        todoUsecase: any TodoEventUsecase,
        scheduleUsecase: any ScheduleEventUsecase,
        eventTagUsease: any EventTagUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.todoUsecase = todoUsecase
        self.scheduleUsecase = scheduleUsecase
        self.eventTagUsease = eventTagUsease
        self.calendarSettingUsecase = calendarSettingUsecase
    }
    
    
    private struct Subject {
        let name = CurrentValueSubject<String?, Never>(nil)
        let isTodo = CurrentValueSubject<Bool, Never>(false)
        let selectedTime = CurrentValueSubject<EventTime?, Never>(nil)
        let selectedTag = CurrentValueSubject<SelectedTag?, Never>(nil)
        let selectedPlace = CurrentValueSubject<SelectPlace?, Never>(nil)
        let url = CurrentValueSubject<String?, Never>(nil)
        let memo = CurrentValueSubject<String?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - AddEventViewModelImple Interactor

extension AddEventViewModelImple {
    
    func enter(name: String) {
        self.subject.name.send(name)
    }
    
    func toggleIsTodo() {
        self.subject.isTodo.send(!self.subject.isTodo.value)
    }
    
    func selectTime() {
        // TODO: show select time picker
    }
    
    func toggleIsAllDay() {
        // TODO: toggle is all day
    }
    
    func selectRepeatOption() {
        // TODO: select repeat option
    }
    
    func selectEventTag() {
        // TODO: select tag
    }
    
    func selectPlace() {
        // TODO: select place
    }
    
    func enter(url: String) {
        self.subject.url.send(url)
    }
    
    func enter(memo: String) {
        self.subject.memo.send(memo)
    }
    
    func showMoreAction() {
        // TODO: show action picker
    }
    
    func save() {
        // TODO: save
    }
}


// MARK: - AddEventViewModelImple Presenter

extension AddEventViewModelImple {
 
    var isTodo: AnyPublisher<Bool, Never> {
        return self.subject.isTodo
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedTime: AnyPublisher<SelectedTime, Never> {
        let transform: (TimeZone, EventTime?) -> SelectedTime = { timeZone, selected in
            let defaultTime: () -> SelectedTime = {
                let now = Date(); let nextHour = now.addingTimeInterval(3600)
                return .period(
                    now.dateText(at: timeZone), now.timeText(at: timeZone),
                    nextHour.dateText(at: timeZone), nextHour.timeText(at: timeZone)
                )
            }
            return selected.map { SelectedTime($0, timeZone) } ?? defaultTime()
        }
        return Publishers.CombineLatest(
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.selectedTime
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var repeatOption: AnyPublisher<String, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    var selectedTag: AnyPublisher<SelectedTag, Never> {
        let transform: (EventTag?, SelectedTag?) -> SelectedTag = { latest, selected in
            return selected ?? latest.map { .init($0) } ?? .defaultTag
        }
        return Publishers.CombineLatest(
            self.eventTagUsease.latestUsedEventTag,
            self.subject.selectedTag
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var selectedPlace: AnyPublisher<SelectPlace?, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    var isSavable: AnyPublisher<Bool, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    var isSaving: AnyPublisher<Bool, Never> {
        Empty().eraseToAnyPublisher()
    }
}

private extension Date {
    
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
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let lhsCompos = calendar.dateComponents([.year, .month, .day], from: self)
        let rhsCompos = calendar.dateComponents([.year, .month, .day], from: other)
        return lhsCompos.year == rhsCompos.year
            && lhsCompos.month == rhsCompos.month
            && lhsCompos.day == rhsCompos.day
    }
}
