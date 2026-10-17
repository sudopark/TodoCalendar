//
//  NextDayEventListViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions
import CalendarPresentation


// MARK: - NextDayEventListViewModel

protocol NextDayEventListViewModel: AnyObject, Sendable, NextDayEventListSceneInteractor {

    var dayModel: AnyPublisher<SelectedDayModel, Never> { get }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> { get }
    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> { get }
}


// MARK: - NextDayEventListViewModelImple

final class NextDayEventListViewModelImple: NextDayEventListViewModel, @unchecked Sendable {

    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let eventLiveActivityUsecase: any EventLiveActivityUsecase
    private let ddayCandidateUsecase: any DDayCandidateUsecase

    init(
        calendarSettingUsecase: any CalendarSettingUsecase,
        uiSettingUsecase: any UISettingUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        eventLiveActivityUsecase: any EventLiveActivityUsecase,
        ddayCandidateUsecase: any DDayCandidateUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.eventLiveActivityUsecase = eventLiveActivityUsecase
        self.ddayCandidateUsecase = ddayCandidateUsecase
    }

    private struct NextDayAndEvents {
        let day: CurrentSelectDayModel
        let events: [any CalendarEvent]
    }

    private struct Subject: @unchecked Sendable {
        let nextDayAndEvents = CurrentValueSubject<NextDayAndEvents?, Never>(nil)
    }
    private let subject = Subject()
}


// MARK: - NextDayEventListViewModelImple Interactor

extension NextDayEventListViewModelImple {

    func nextDayChanged(_ nextDay: CurrentSelectDayModel, and eventsThatDay: [any CalendarEvent]) {
        self.subject.nextDayAndEvents.send(.init(day: nextDay, events: eventsThatDay))
    }
}


// MARK: - NextDayEventListViewModelImple Presenter

extension NextDayEventListViewModelImple {

    var dayModel: AnyPublisher<SelectedDayModel, Never> {
        return Publishers.CombineLatest(
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.nextDayAndEvents.compactMap { $0?.day }
        )
        .map { SelectedDayModel($0, currentModel: $1) }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> {
        let asCellViewModels: (NextDayAndEvents, TimeZone, Bool) -> [any EventCellViewModel]
        asCellViewModels = { dayAndEvents, timeZone, is24HourForm in
            let mapper = EventCellViewModelMapper(
                range: dayAndEvents.day.range, timeZone: timeZone, is24hourForm: is24HourForm
            )
            return mapper.cellViewModels(from: dayAndEvents.events.sortedByEventTime())
                .filter { !$0.isForemost }
        }
        let applyRegistration: (
            [any EventCellViewModel], LiveActivityTarget?, [DDayCandidate]
        ) -> [any EventCellViewModel]
        applyRegistration = { cvms, target, candidates in
            cvms.map {
                $0.liveActivityRegistrationApplied(target)
                    .ddayCandidateRegistrationApplied(candidates)
            }
        }

        let cells = Publishers.CombineLatest3(
            self.subject.nextDayAndEvents.compactMap { $0 },
            self.calendarSettingUsecase.currentTimeZone,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }.removeDuplicates()
        )
        .map(asCellViewModels)

        return Publishers.CombineLatest3(
            cells,
            self.eventLiveActivityUsecase.registeredTarget,
            self.ddayCandidateUsecase.candidates
        )
            .map(applyRegistration)
            .removeDuplicates(by: { $0.map { $0.customCompareKey } == $1.map { $0.customCompareKey } })
            .eraseToAnyPublisher()
    }

    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> {
        return self.foremostEventUsecase.foremostEventMarkingStatus
    }
}
