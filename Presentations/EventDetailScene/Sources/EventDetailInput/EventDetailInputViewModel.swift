//
//  EventDetailInputViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/2/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes
import CommonPresentation


// MARK: - event detail input interactor + listener

protocol EventDetailInputInteractor: AnyObject {
    func prepared(basic: EventDetailBasicData, additional: EventDetailData)
}

protocol EventDetailInputListener: AnyObject {
    
    func eventDetail(didInput basic: EventDetailBasicData, additional: EventDetailData)
}


// MARK: - event detail input routing


protocol EventDetailInputRouting: Routing, Sendable, AnyObject {
    
    func routeToEventRepeatOptionSelect(
        startTime: Date,
        with initalOption: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    )
    
    func routeToEventTagSelect(
        currentSelectedTagId: AllEventTagId,
        listener: (any SelectEventTagSceneListener)?
    )
    
    func routeToEventNotificationTimeSelect(
        isForAllDay: Bool,
        current selecteds: [EventNotificationTimeOption],
        eventTimeComponents: DateComponents,
        listener: (any SelectEventNotificationTimeSceneListener)?
    )
}


struct LinkPreviewModel {
    let title: String
    var description: String?
    var imageUrl: String?
    
    init(title: String, description: String? = nil, imageUrl: String? = nil) {
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
    }
    
    init?(_ preview: LinkPreview) {
        guard let title = preview.title else { return nil }
        self.title = title
        self.description = preview.description ?? preview.url?.absoluteString
        self.imageUrl = preview.mainImagePath ?? preview.images.first
    }
}

// MARK: - EventDetailInputViewModel

protocol EventDetailInputViewModel: Sendable, AnyObject, EventDetailInputInteractor {
    
    var listener: (any EventDetailInputListener)? { get set }
    
    func setup()
    func enter(name: String)
    func selectStartTime(_ date: Date)
    func selectEndtime(_ date: Date)
    func removeTime()
    func removeEventEndTime()
    func toggleIsAllDay()
    func selectRepeatOption()
    func selectEventTag()
    func selectNotificationTime()
    func selectPlace()
    func enter(url: String)
    func enter(memo: String)
    func openURL()
    
    var initialName: AnyPublisher<String?, Never> { get }
    var initailURL: AnyPublisher<String?, Never> { get }
    var initialMemo: AnyPublisher<String?, Never> { get }
    func startTimeDefaultDate(for now: Date) -> Date
    func endTimeDefaultDate(from startDate: Date) -> Date
    var selectedTime: AnyPublisher<SelectedTime?, Never> { get }
    var repeatOption: AnyPublisher<String?, Never> { get }
    var selectedTag: AnyPublisher<SelectedTag, Never> { get }
    var selectedPlace: AnyPublisher<Place?, Never> { get }
    var selectedNotificationTimeText: AnyPublisher<String?, Never> { get }
    var isValidURLEntered: AnyPublisher<Bool, Never> { get }
    var linkPreview: AnyPublisher<LinkPreviewModel?, Never> { get }
}


final class EventDetailInputViewModelImple: EventDetailInputViewModel, @unchecked Sendable {
    
    private let eventTagUsecase: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let eventSettingUsecase: any EventSettingUsecase
    private let linkPreviewFetchUsecase: any LinkPreviewFetchUsecase
    weak var routing: (any EventDetailInputRouting)?
    weak var listener: (any EventDetailInputListener)?
    
    init(
        eventTagUsecase: any EventTagUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventSettingUsecase: any EventSettingUsecase,
        linkPreviewFetchUsecase: any LinkPreviewFetchUsecase
    ) {
        self.eventTagUsecase = eventTagUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.eventSettingUsecase = eventSettingUsecase
        self.linkPreviewFetchUsecase = linkPreviewFetchUsecase
    }
    
    private struct BasicAndTimeZoneData {
        var basic: EventDetailBasicData
        let timeZone: TimeZone
    }

    private struct Subject {
        let basic = CurrentValueSubject<BasicAndTimeZoneData?, Never>(nil)
        let additional = CurrentValueSubject<EventDetailData?, Never>(nil)
        let eventSetting = CurrentValueSubject<EventSettings?, Never>(nil)
        let linkPreview = CurrentValueSubject<LinkPreview?, Never>(nil)
        
        func mutateBasicIfPossible(
            _ mutating: (BasicAndTimeZoneData) -> BasicAndTimeZoneData?
        ) {
            guard let old = self.basic.value,
                  let new = mutating(old)
            else { return }
            self.basic.send(new)
        }
        
        func mutateAdditionalIfPossible(
            _ mutating: (EventDetailData) -> EventDetailData?
        ) {
            guard let old = self.additional.value,
                    let new = mutating(old)
            else { return }
            self.additional.send(new)
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - prepare and select time

extension EventDetailInputViewModelImple {
    
    func setup() {
        Publishers.CombineLatest(
            self.subject.basic.compactMap { $0?.basic }.removeDuplicates(),
            self.subject.additional.compactMap { $0 }.removeDuplicates()
        )
        .sink(receiveValue: { [weak self] (basic, additional) in
            self?.listener?.eventDetail(didInput: basic, additional: additional)
        })
        .store(in: &self.cancellables)
        
        let setting = self.eventSettingUsecase.loadEventSetting()
        self.subject.eventSetting.send(setting)
        
        self.bindLinkPreview()
    }
    
    private func bindLinkPreview() {
        
        self.subject.additional
            .map { $0?.url?.asURL() }
            .throttle(for: .milliseconds(300), scheduler: RunLoop.main, latest: true)
            .removeDuplicates()
            .map { url -> AnyPublisher<LinkPreview?, Never> in
                guard let url = url else { return Just(nil).eraseToAnyPublisher() }
                return Publishers.create(do: { [weak self] in
                    return try await self?.linkPreviewFetchUsecase.fetchPreview(url)
                })
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink(receiveValue: { [weak self] preview in
                self?.subject.linkPreview.send(preview)
            })
            .store(in: &self.cancellables)
    }
    
    func prepared(basic: EventDetailBasicData, additional: EventDetailData) {
        
        let update: (TimeZone) -> Void = { [weak self] timeZone in
            let basicAndTimeZone = BasicAndTimeZoneData(basic: basic, timeZone: timeZone)
            self?.subject.basic.send(basicAndTimeZone)
            self?.subject.additional.send(additional)
        }
        self.calendarSettingUsecase.currentTimeZone
            .compactMap { $0 }
            .first()
            .sink(receiveValue: update)
            .store(in: &self.cancellables)
    }
    
    func enter(name: String) {
        self.subject.mutateBasicIfPossible {
            $0 |> \.basic.name .~ name
        }
    }
    
    func selectStartTime(_ date: Date) {
        self.subject.mutateBasicIfPossible { data in
            return data
            |> \.basic.selectedTime %~ { $0.periodStartChanged(date, data.timeZone)}
            |> \.basic.eventRepeating %~ { $0?.updateRepeatStartTime(date.timeIntervalSince1970, data.timeZone)}
        }
    }
    
    func selectEndtime(_ date: Date) {
        self.subject.mutateBasicIfPossible { data in
            guard let newTime = data.basic.selectedTime.periodEndTimeChanged(date, data.timeZone)
            else { return nil }
            return data |> \.basic.selectedTime .~ newTime
        }
    }
    
    func removeTime() {
        self.subject.mutateBasicIfPossible {
            return $0
                |> \.basic.selectedTime .~  nil
                |> \.basic.eventRepeating .~ nil
                |> \.basic.eventNotifications .~ []
        }
    }
    
    func removeEventEndTime() {
        self.subject.mutateBasicIfPossible { data in
            guard let newTime = data.basic.selectedTime.removePeriodEndTime(data.timeZone)
            else { return nil }
            return data |> \.basic.selectedTime .~ newTime
        }
    }
    
    func toggleIsAllDay() {
        self.subject.mutateBasicIfPossible { data in
            data 
                |> \.basic.selectedTime %~ { $0?.toggleIsAllDay(data.timeZone) }
                |> \.basic.eventNotifications .~ []
        }
    }
}


// MARK: - repeat option

extension EventDetailInputViewModelImple: SelectEventRepeatOptionSceneListener {
    
    func selectRepeatOption() {
        guard let basic = self.subject.basic.value,
              let time = basic.basic.selectedTime
        else {
            self.routing?.showToast(R.String.EventDetail.Messages.selectTimeFirst)
            return
        }
        
        guard let eventTime = time.eventTime(basic.timeZone)
        else {
            self.routing?.showToast(R.String.EventDetail.Messages.selectValidTime)
            return
        }
        
        self.routing?.routeToEventRepeatOptionSelect(
            startTime: Date(timeIntervalSince1970: eventTime.lowerBoundWithFixed),
            with: basic.basic.eventRepeating?.repeating,
            listener: self)
    }
    
    func selectEventRepeatOption(didSelect repeating: EventRepeatingTimeSelectResult) {
        self.subject.mutateBasicIfPossible {
            return $0 |> \.basic.eventRepeating .~ repeating
        }
    }
    
    func selectEventRepeatOptionNotRepeat() {
        self.subject.mutateBasicIfPossible {
            return $0 |> \.basic.eventRepeating .~ nil
        }
    }
}


// MARK: - event tag

extension EventDetailInputViewModelImple: SelectEventTagSceneListener {
    
    func selectEventTag() {
        guard let tagId = self.subject.basic.value?.basic.eventTagId
        else { return }
        self.routing?.routeToEventTagSelect(
            currentSelectedTagId: tagId,
            listener: self
        )
    }
    
    func selectEventTag(didSelected tag: SelectedTag) {
        self.subject.mutateBasicIfPossible {
            return $0 |> \.basic.eventTagId .~ tag.tagId
        }
    }
}


// MARK: - select notification time

extension EventDetailInputViewModelImple: SelectEventNotificationTimeSceneListener {
    
    func selectNotificationTime() {
        guard let basicAndTimeZone = self.subject.basic.value,
              let (eventTime, isAllDay) = basicAndTimeZone.basic.selectedTime?.evnetTimeAndIsAllDay
        else {
            self.routing?.showToast(R.String.EventDetail.Messages.selectTimeFirst)
            return
        }
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ basicAndTimeZone.timeZone
        let eventTimeComponents = calendar.dateComponents([
            .year, .month, .day, .hour, .minute, .second
        ], from: eventTime)
        self.routing?.routeToEventNotificationTimeSelect(
            isForAllDay: isAllDay,
            current: basicAndTimeZone.basic.eventNotifications,
            eventTimeComponents: eventTimeComponents,
            listener: self
        )
    }
    
    func selectEventNotificationTime(
        didUpdate selectedTimeOptions: [EventNotificationTimeOption]
    ) {
        
        self.subject.mutateBasicIfPossible {
            $0 |> \.basic.eventNotifications .~ selectedTimeOptions
        }
    }
    
    var selectedNotificationTimeText: AnyPublisher<String?, Never> {
        let transform: (BasicAndTimeZoneData) -> String? = { data in
            guard !data.basic.eventNotifications.isEmpty
            else {
                return nil
            }
            let texts = data.basic.eventNotifications.map { $0.text }
            return texts.andJoin()
        }
        return self.subject.basic
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

extension EventDetailInputViewModelImple {
    
    func selectPlace() {
        // TOOD: select place
    }
    
    func enter(url: String) {
        self.subject.mutateAdditionalIfPossible {
            return $0 |> \.url .~ url
        }
    }
    
    
    func openURL() {
        guard let url = self.subject.additional.value?.url, !url.isEmpty else { return }
        self.routing?.openSafari(url)
    }
    
    func enter(memo: String) {
        self.subject.mutateAdditionalIfPossible {
            return $0 |> \.memo .~ memo
        }
    }
    
    var isValidURLEntered: AnyPublisher<Bool, Never> {
        return self.subject.additional
            .map { $0?.url?.asURL() }
            .map { $0 != nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var linkPreview: AnyPublisher<LinkPreviewModel?, Never> {
        return self.subject.linkPreview
            .map { preview in preview.flatMap { LinkPreviewModel($0) } }
            .eraseToAnyPublisher()
    }
}


extension EventDetailInputViewModelImple {
    
    var initialName: AnyPublisher<String?, Never> {
        return self.subject.basic
            .compactMap { $0 }
            .map { $0.basic.name }
            .first()
            .eraseToAnyPublisher()
    }
    
    var initailURL: AnyPublisher<String?, Never> {
        return self.subject.additional
            .compactMap { $0 }
            .map { $0.url }
            .first()
            .eraseToAnyPublisher()
    }
    var initialMemo: AnyPublisher<String?, Never> {
        return self.subject.additional
            .compactMap { $0 }
            .map { $0.memo }
            .first()
            .eraseToAnyPublisher()
    }
    
    func startTimeDefaultDate(for now: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let minutes = calendar.component(.minute, from: now)
        let (quotient, remainder) = minutes.quotientAndRemainder(dividingBy: 5)
        let newMinutes = remainder == 0 ? minutes : (quotient + 1) * 5
        let interval = newMinutes - minutes
        return now.addingTimeInterval(TimeInterval(interval) * 60)
    }
    
    func endTimeDefaultDate(from startDate: Date) -> Date {
        let period = self.subject.eventSetting.value?.defaultNewEventPeriod ?? .hour1
        let suggestingEndtimeInterval = switch period {
        case .minute0: 60 * 60
        case .minute5: 60 * 5
        case .minute10: 60 * 10
        case .minute15: 60 * 15
        case .minute30: 60 * 30
        case .minute45: 60 * 45
        case .hour1: 60 * 60
        case .hour2: 60 * 120
        case .allDay: 60 * 60
        }
        return startDate.addingTimeInterval(TimeInterval(suggestingEndtimeInterval))
    }
    
    var selectedTime: AnyPublisher<SelectedTime?, Never> {
        return self.subject.basic
            .compactMap { $0 }
            .map { $0.basic.selectedTime }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var repeatOption: AnyPublisher<String?, Never> {
        return self.subject.basic
            .compactMap { $0 }
            .map { $0.basic.eventRepeating?.text }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedTag: AnyPublisher<SelectedTag, Never> {
        let transform: (AllEventTagId) -> AnyPublisher<SelectedTag, Never> = { [weak self] eventId in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            switch eventId {
            case .default:
                return Just(SelectedTag.defaultTag).eraseToAnyPublisher()
            case .holiday:
                return Just(SelectedTag.holiday).eraseToAnyPublisher()
            case .custom(let id):
                return self.eventTagUsecase.eventTag(id: id)
                    .map { SelectedTag($0) }
                    .eraseToAnyPublisher()
            }
        }
        
        return self.subject.basic
            .compactMap { $0 }
            .map { $0.basic.eventTagId }
            .flatMap(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedPlace: AnyPublisher<Place?, Never> {
        return Just(nil).eraseToAnyPublisher()
    }
}

private extension SelectedTime {
    
    var evnetTimeAndIsAllDay: (Date, Bool) {
        switch self {
        case .at(let time):
            return (time.date, false)
        case .period(let start, _):
            return (start.date, false)
        case .singleAllDay(let time):
            return (time.date, true)
        case .alldayPeriod(let start, _):
            return (start.date, true)
        }
    }
}
