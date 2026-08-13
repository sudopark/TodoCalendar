//
//  EventListCellEventHanleViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 6/28/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes
import Extensions

enum DoneTodoResult {
    case success(_ id: String)
    case failed(_ id: String, reason: any Error)
    
    var id: String {
        switch self {
        case .success(let id): return id
        case .failed(let id, _): return id
        }
    }
}

protocol EventListCellEventHanleViewModel: EventDetailSceneListener {
    
    func selectEvent(_ model: any EventCellViewModel)
    func doneTodo(_ eventId: String)
    func cancelDoneTodo(_ eventId: String)
    func handleMoreAction(
        _ cellViewModel: any EventCellViewModel,
        _ action: EventListMoreAction
    )
    
    var doneTodoResult: AnyPublisher<DoneTodoResult, Never> { get }
}


final class EventListCellEventHanleViewModelImple: EventListCellEventHanleViewModel, @unchecked Sendable {

    private let todoEventUsecase: any TodoEventUsecase
    private let scheduleEventUsecase: any ScheduleEventUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let externalCalendarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    private let liveActivityToggleViewModel: any LiveActivityToggleViewModel

    var router: (any EventListCellEventHanleRouting)?

    init(
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        externalCalendarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        liveActivityToggleViewModel: any LiveActivityToggleViewModel
    ) {
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
        self.externalCalendarIntegrationUsecase = externalCalendarIntegrationUsecase
        self.liveActivityToggleViewModel = liveActivityToggleViewModel

        self.internalBind()
    }

    private struct Subject {
        let doneTodoResult = PassthroughSubject<DoneTodoResult, Never>()
        let registeredLiveActivityTarget = CurrentValueSubject<LiveActivityTarget?, Never>(nil)
    }
    private var cancellables: Set<AnyCancellable> = []
    private var todoCompleteTaskMap: [String: Task<Void, any Error>] = [:]
    private let subject = Subject()

    private func internalBind() {
        self.liveActivityToggleViewModel.registeredTarget
            .sink { [weak self] target in
                self?.subject.registeredLiveActivityTarget.send(target)
            }
            .store(in: &self.cancellables)
    }
}

extension EventListCellEventHanleViewModelImple {
    
    func selectEvent(_ model: any EventCellViewModel) {
        switch model {
        case let todo as TodoEventCellViewModel:
            self.router?.routeToTodoEventDetail(todo.eventIdentifier)
            
        case let schedule as ScheduleEventCellViewModel:
            self.router?.routeToScheduleEventDetail(
                schedule.eventIdWithoutTurn,
                schedule.eventTimeRawValue
            )
            
        case let google as GoogleCalendarEventCellViewModel:
            self.router?.routeToGoogleEventDetail(
                calendarId: google.calendarId, accountId: google.accountId, eventId: google.eventIdentifier
            )

        case let apple as AppleCalendarEventCellViewModel:
            self.router?.routeToAppleCalendarEventDetail(
                calendarId: apple.calendarId, eventId: apple.eventIdentifier
            )

        case let holiday as HolidayEventCellViewModel:
            self.router?.routeToHolidayEventDetail(holiday.eventIdentifier)
            
        default: break
        }
    }
    
    func doneTodo(_ eventId: String) {
        self.cancelDoneTodo(eventId)
        self.todoCompleteTaskMap[eventId] = Task { [weak self] in
            do {
                _ = try await self?.todoEventUsecase.completeTodo(eventId)
                self?.subject.doneTodoResult.send(
                    .success(eventId)
                )
            } catch {
                self?.subject.doneTodoResult.send(
                    .failed(eventId, reason: error)
                )
                guard !(error is CancellationError) else { return }
                self?.router?.showError(error)
            }
        }
    }
    
    func cancelDoneTodo(_ eventId: String) {
        self.todoCompleteTaskMap[eventId]?.cancel()
        self.todoCompleteTaskMap[eventId] = nil
    }
    
    func handleMoreAction(
        _ cellViewModel: any EventCellViewModel,
        _ action: EventListMoreAction
    ) {
        
        switch action {
        case .remove(let onlyThisTime):
            self.removeEvent(cellViewModel, onlyThisTime)
            
        case .toggleTo(let isForemost):
            self.toggleForemostEvent(cellViewModel, isForemost)

        case .toggleLiveActivity(let isRegistered):
            self.toggleLiveActivity(cellViewModel, isRegistered)

        case .edit:
            self.selectEvent(cellViewModel)
            
        case .skipTodo:
            guard let todo = cellViewModel as? TodoEventCellViewModel else { return }
            self.skipTodoToNext(todo)
            
        case .copy:
            self.copyEvent(cellViewModel)
            
        case .editGoogleEvent(let calendarId, let accountId, let eventId):
            self.editGoogleEvent(calendarId: calendarId, accountId: accountId, eventId: eventId)
        }
    }

    private func editGoogleEvent(calendarId: String, accountId: String, eventId: String) {
        self.googleCalendarUsecase.eventWritePermission(accountId: accountId, calendarId: calendarId)
            .first()
            .sink(receiveValue: { [weak self] permission in
                self?.handleGoogleEventWritePermission(
                    permission, calendarId: calendarId, accountId: accountId, eventId: eventId
                )
            })
            .store(in: &self.cancellables)
    }

    private func handleGoogleEventWritePermission(
        _ permission: GoogleCalendar.EventWritePermission,
        calendarId: String, accountId: String, eventId: String
    ) {
        switch permission {
        case .writable:
            self.router?.routeToEditGoogleEvent(calendarId: calendarId, accountId: accountId, eventId: eventId)

        case .needReauthentication:
            let title = "eventDetail::gogoleEvent::reauthenticate::title".localized()
            let message = "eventDetail::gogoleEvent::reauthenticate::message".localized()
            self.runMoreActionAfterConfirm(title, message) { [weak self] in
                self?.reauthenticateThenRouteToEditGoogleEvent(
                    calendarId: calendarId, accountId: accountId, eventId: eventId
                )
            }

        case .readOnlyCalendar:
            self.router?.showToast("eventDetail::gogoleEvent::readOnlyCalendar::message".localized())
        }
    }

    private func reauthenticateThenRouteToEditGoogleEvent(
        calendarId: String, accountId: String, eventId: String
    ) {
        let service = self.googleCalendarUsecase.googleService
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.externalCalendarIntegrationUsecase.reauthenticate(
                    external: service, accountId: accountId
                )
                self.router?.routeToEditGoogleEvent(calendarId: calendarId, accountId: accountId, eventId: eventId)
            } catch {
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }

    private func removeEvent(
        _ cellViewModel: any EventCellViewModel,
        _ onlyThisTime: Bool
    ) {

        let title = R.String.calendarEventMoreActionRemoveTitle
        let message = onlyThisTime
            ? R.String.calendarEventMoreActionRemoveOnlyThistimeMessage
            : R.String.calendarEventMoreActionRemoveMessage
        self.runMoreActionAfterConfirm(title, message) { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    switch cellViewModel {
                    case let todo as TodoEventCellViewModel:
                        try await self?.todoEventUsecase.removeTodo(
                            todo.eventIdentifier, onlyThisTime: onlyThisTime
                        )
                    case let schedule as ScheduleEventCellViewModel:
                        let time = onlyThisTime ? schedule.eventTimeRawValue : nil
                        try await self?.scheduleEventUsecase.removeScheduleEvent(
                            schedule.eventIdWithoutTurn, onlyThisTime: time
                        )
                    default: break
                    }
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }
    
    private func toggleForemostEvent(
        _ cellViewModel: any EventCellViewModel,
        _ newValue: Bool
    )  {
        
        if newValue && cellViewModel.isRepeatingSchedule {
            self.showUnavailToMarkRepeatingScheduleAsForemostEvent()
            return
        }
        
        let title = R.String.calendarEventMoreActionForemostEventTitle
        let message = newValue
            ? R.String.calendarEventMoreActionMarkAsForemost
            : R.String.calendarEventMoreActionUnmarkAsForemost
        self.runMoreActionAfterConfirm(title, message) { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    switch (cellViewModel, newValue) {
                    case (_, false):
                        try await self?.foremostEventUsecase.remove()
                    case (let todo as TodoEventCellViewModel, _):
                        try await self?.foremostEventUsecase.update(
                            foremost: .init(todo.eventIdentifier, true)
                        )
                    case (let schedule as ScheduleEventCellViewModel, _):
                        try await self?.foremostEventUsecase.update(
                            foremost: .init(schedule.eventIdWithoutTurn, false)
                        )
                    default: break
                    }
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }
    
    private func toggleLiveActivity(
        _ cellViewModel: any EventCellViewModel,
        _ isRegistered: Bool
    ) {
        guard let target = cellViewModel.liveActivityTarget else { return }

        let title = "calendar::event::more_action:live_activity:title".localized()
        let message = self.toggleLiveActivityConfirmMessage(isRegistered, target: target)
        self.runMoreActionAfterConfirm(title, message) { [weak self] in
            self?.liveActivityToggleViewModel.startOrStopLiveActivity(target, isCurrentlyRegistered: isRegistered)
        }
    }

    private func toggleLiveActivityConfirmMessage(
        _ isRegistered: Bool, target: LiveActivityTarget
    ) -> String {
        guard !isRegistered else {
            return "calendar::event::more_action:live_activity:unregister:confirm".localized()
        }
        let currentlyRegisteredTarget = self.subject.registeredLiveActivityTarget.value
        let isReplacingOtherTarget = currentlyRegisteredTarget != nil && currentlyRegisteredTarget != target
        return isReplacingOtherTarget
            ? "calendar::event::more_action:live_activity:replace:confirm".localized()
            : "calendar::event::more_action:live_activity:register:confirm".localized()
    }

    private func showUnavailToMarkRepeatingScheduleAsForemostEvent() {
        let info = ConfirmDialogInfo()
            |> \.title .~ "calendar::event::more_action::foremost_event:title".localized()
            |> \.message .~ "calendar::event::more_action::mark_as_foremost::unavail".localized()
            |> \.withCancel .~ false
            |> \.confirmText .~ "common.close".localized()
        self.router?.showConfirm(dialog: info)
    }
    
    private func skipTodoToNext(_ cellViewModel: TodoEventCellViewModel) {
        Task { [weak self] in
            do {
                _ = try await self?.todoEventUsecase.skipRepeatingTodo(cellViewModel.eventIdentifier)
            } catch {
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func copyEvent(_ cellViewModel: any EventCellViewModel) {
        switch cellViewModel {
        case let todo as TodoEventCellViewModel:
            self.router?.routeToMakeNewEvent(
                .init(selectedDate: Date(), makeSource: .todoFromCopy(todo.eventIdentifier))
            )
        case let schedule as ScheduleEventCellViewModel:
            self.router?.routeToMakeNewEvent(
                .init(selectedDate: Date(), makeSource: .scheduleFromCopy(schedule.eventIdWithoutTurn))
            )
        default: return
        }
    }
    
    private func runMoreActionAfterConfirm(
        _ title: String, _ message: String,
        _ action: @escaping () -> Void
    ) {
        let info = ConfirmDialogInfo()
            |> \.title .~ title
            |> \.message .~ pure(message)
            |> \.confirmed .~ pure(action)
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }
}

// MARK: - handle event detail scene listener

extension EventListCellEventHanleViewModelImple {
    
    func eventDetail(
        copyFromTodo params: TodoMakeParams, detail: EventDetailData?
    ) {
        self.router?.routeToMakeNewEvent(
            .init(selectedDate: Date(), makeSource: .todoWith(params, detail))
        )
    }
    
    func eventDetail(
        copyFromSchedule schedule: ScheduleMakeParams, detail: EventDetailData?
    ) {
        self.router?.routeToMakeNewEvent(
            .init(selectedDate: Date(), makeSource: .scheduleWith(schedule, detail))
        )
    }
    
    func eventDetail(transformTo schedule: ScheduleEvent) {
        self.router?.routeToScheduleEventDetail(schedule.uuid, nil)
    }
    
    func eventDetail(transformTo todo: TodoEvent) {
        self.router?.routeToTodoEventDetail(todo.uuid)
    }
}

extension EventListCellEventHanleViewModelImple {
    
    var doneTodoResult: AnyPublisher<DoneTodoResult, Never> {
        return self.subject.doneTodoResult
            .eraseToAnyPublisher()
    }
}

private extension EventCellViewModel {
    
    var isRepeatingSchedule: Bool {
        return (self as? ScheduleEventCellViewModel)?.isRepeating == true
    }
}
