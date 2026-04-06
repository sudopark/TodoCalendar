//
//  AppleCalendarEventDetailViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - AppleCalendarTagModel

struct AppleCalendarTagModel: Equatable {
    let calendarId: String
    let name: String
}


// MARK: - AppleCalendarEventDetailViewModel

protocol AppleCalendarEventDetailViewModel: AnyObject, Sendable, AppleCalendarEventDetailSceneInteractor {

    // interactor
    func refresh()
    func openInAppleCalendar()
    func openURL(_ urlString: String)
    func close()

    // presenter
    var eventName: AnyPublisher<String, Never> { get }
    var timeText: AnyPublisher<SelectedTime?, Never> { get }
    var ddayText: AnyPublisher<String, Never> { get }
    var location: AnyPublisher<String?, Never> { get }
    var url: AnyPublisher<String?, Never> { get }
    var notes: AnyPublisher<String?, Never> { get }
    var tagModel: AnyPublisher<AppleCalendarTagModel?, Never> { get }
}


// MARK: - AppleCalendarEventDetailViewModelImple

final class AppleCalendarEventDetailViewModelImple: AppleCalendarEventDetailViewModel, @unchecked Sendable {

    private let calendarId: String
    private let eventId: String
    private let appleCalendarUsecase: any AppleCalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let daysIntervalCountUsecase: any DaysIntervalCountUsecase
    var router: (any AppleCalendarEventDetailRouting)?

    init(
        calendarId: String,
        eventId: String,
        appleCalendarUsecase: any AppleCalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        daysIntervalCountUsecase: any DaysIntervalCountUsecase
    ) {
        self.calendarId = calendarId
        self.eventId = eventId
        self.appleCalendarUsecase = appleCalendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.daysIntervalCountUsecase = daysIntervalCountUsecase

        self.internalBind()
    }

    private struct Subject {
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let event = CurrentValueSubject<AppleCalendar.EventOrigin?, Never>(nil)
        let calendarTag = CurrentValueSubject<AppleCalendar.Tag?, Never>(nil)
    }

    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()

    private func internalBind() {

        self.calendarSettingUsecase.currentTimeZone
            .sink { [weak self] timeZone in
                self?.subject.timeZone.send(timeZone)
            }
            .store(in: &self.cancellables)

        let calendarId = self.calendarId
        self.appleCalendarUsecase.calendarTags
            .map { tags in tags.first(where: { $0.id == calendarId }) }
            .sink { [weak self] tag in
                self?.subject.calendarTag.send(tag)
            }
            .store(in: &self.cancellables)
    }
}


// MARK: - AppleCalendarEventDetailViewModelImple Interactor

extension AppleCalendarEventDetailViewModelImple {

    func refresh() {
        self.appleCalendarUsecase.eventOrigin(id: self.eventId)
            .compactMap { $0 }
            .sink { [weak self] origin in
                self?.subject.event.send(origin)
            }
            .store(in: &self.cancellables)
    }

    func openInAppleCalendar() {
        guard let origin = self.subject.event.value else { return }
        let startInterval = origin.eventTime.lowerBoundWithFixed
        self.router?.routeToAppleCalendarApp(at: startInterval)
    }

    func openURL(_ urlString: String) {
        self.router?.openURL(urlString)
    }

    func close() {
        self.router?.closeScene()
    }
}


// MARK: - AppleCalendarEventDetailViewModelImple Presenter

extension AppleCalendarEventDetailViewModelImple {

    var eventName: AnyPublisher<String, Never> {
        return self.subject.event
            .compactMap { $0 }
            .map { $0.name }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var timeText: AnyPublisher<SelectedTime?, Never> {
        return Publishers.CombineLatest(
            self.subject.event.compactMap { $0 },
            self.subject.timeZone.compactMap { $0 }
        )
        .map { event, timeZone -> SelectedTime? in
            return SelectedTime(event.eventTime, timeZone)
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var ddayText: AnyPublisher<String, Never> {
        let countDays: (AppleCalendar.EventOrigin, TimeZone) -> AnyPublisher<Int, Never> = { [weak self] event, _ in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.daysIntervalCountUsecase.countDays(to: event.eventTime)
        }

        return Publishers.CombineLatest(
            self.subject.event.compactMap { $0 },
            self.subject.timeZone.compactMap { $0 }
        )
        .map(countDays)
        .switchToLatest()
        .removeDuplicates()
        .map { DDayText($0).text }
        .eraseToAnyPublisher()
    }

    var location: AnyPublisher<String?, Never> {
        return self.subject.event
            .compactMap { $0 }
            .map { $0.location }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var url: AnyPublisher<String?, Never> {
        return self.subject.event
            .compactMap { $0 }
            .map { $0.url }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var notes: AnyPublisher<String?, Never> {
        return self.subject.event
            .compactMap { $0 }
            .map { $0.notes }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var tagModel: AnyPublisher<AppleCalendarTagModel?, Never> {
        return self.subject.calendarTag
            .map { tag in
                tag.map { AppleCalendarTagModel(calendarId: $0.id, name: $0.name) }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
