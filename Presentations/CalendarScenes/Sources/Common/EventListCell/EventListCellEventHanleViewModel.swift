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
    private let appleCalendarUsecase: any AppleCalendarUsecase
    private let externalCalendarIntegrationUsecase: any ExternalCalendarIntegrationUsecase

    var router: (any EventListCellEventHanleRouting)?

    init(
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        appleCalendarUsecase: any AppleCalendarUsecase,
        externalCalendarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    ) {
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
        self.appleCalendarUsecase = appleCalendarUsecase
        self.externalCalendarIntegrationUsecase = externalCalendarIntegrationUsecase
    }
    
    private struct Subject {
        let doneTodoResult = PassthroughSubject<DoneTodoResult, Never>()
    }
    private var cancellables: Set<AnyCancellable> = []
    private var todoCompleteTaskMap: [String: Task<Void, any Error>] = [:]
    private let subject = Subject()
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
        case .remove(let scope):
            self.removeEvent(cellViewModel, scope)
            
        case .toggleTo(let isForemost):
            self.toggleForemostEvent(cellViewModel, isForemost)
            
        case .edit:
            self.selectEvent(cellViewModel)
            
        case .skipTodo:
            guard let todo = cellViewModel as? TodoEventCellViewModel else { return }
            self.skipTodoToNext(todo)
            
        case .copy:
            self.copyEvent(cellViewModel)
        }
    }

    private func removeEvent(
        _ cellViewModel: any EventCellViewModel,
        _ scope: EventListRemoveScope
    ) {
        guard let google = cellViewModel as? GoogleCalendarEventCellViewModel else {
            self.confirmAndRemoveEvent(cellViewModel, scope)
            return
        }
        self.googleCalendarUsecase
            .eventWritePermission(accountId: google.accountId, calendarId: google.calendarId)
            .first()
            .sink { [weak self] permission in
                switch permission {
                case .writable:
                    self?.confirmAndRemoveEvent(google, scope)
                case .needReauthentication:
                    self?.confirmReauthenticateThenRemove(google, scope)
                case .readOnlyCalendar:
                    break
                }
            }
            .store(in: &self.cancellables)
    }

    private func confirmReauthenticateThenRemove(
        _ google: GoogleCalendarEventCellViewModel,
        _ scope: EventListRemoveScope
    ) {
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("eventDetail::gogoleEvent::reauthenticate::title".localized())
            |> \.message .~ pure("eventDetail::gogoleEvent::reauthenticate::message".localized())
            |> \.confirmed .~ pure({ [weak self] in self?.reauthenticateThenRemove(google, scope) })
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }

    private func reauthenticateThenRemove(
        _ google: GoogleCalendarEventCellViewModel,
        _ scope: EventListRemoveScope
    ) {
        let service = self.googleCalendarUsecase.googleService
        let accountId = google.accountId
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.externalCalendarIntegrationUsecase.reauthenticate(
                    external: service, accountId: accountId
                )
                self.confirmAndRemoveEvent(google, scope)
            } catch {
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }

    private func confirmAndRemoveEvent(
        _ cellViewModel: any EventCellViewModel,
        _ scope: EventListRemoveScope
    ) {
        let title = R.String.calendarEventMoreActionRemoveTitle
        let message = self.removeConfirmMessage(scope)
        self.runMoreActionAfterConfirm(title, message) { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    try await self?.executeRemove(cellViewModel, scope)
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }

    private func executeRemove(
        _ cellViewModel: any EventCellViewModel,
        _ scope: EventListRemoveScope
    ) async throws {
        switch cellViewModel {
        case let todo as TodoEventCellViewModel:
            switch scope {
            case .onlyThisTime:
                try await self.todoEventUsecase.removeTodo(
                    todo.eventIdentifier, onlyThisTime: true
                )
            case .all:
                try await self.todoEventUsecase.removeTodo(
                    todo.eventIdentifier, onlyThisTime: false
                )
            case .thisAndFuture:
                break
            }
        case let schedule as ScheduleEventCellViewModel:
            switch scope {
            case .onlyThisTime:
                try await self.scheduleEventUsecase.removeScheduleEvent(
                    schedule.eventIdWithoutTurn, onlyThisTime: schedule.eventTimeRawValue
                )
            case .all:
                try await self.scheduleEventUsecase.removeScheduleEvent(
                    schedule.eventIdWithoutTurn, onlyThisTime: nil
                )
            case .thisAndFuture:
                break
            }
        case let google as GoogleCalendarEventCellViewModel:
            try await self.removeGoogleEvent(google, scope)
        case let apple as AppleCalendarEventCellViewModel:
            try await self.removeAppleEvent(apple, scope)
        default: break
        }
    }

    private func removeGoogleEvent(
        _ google: GoogleCalendarEventCellViewModel,
        _ scope: EventListRemoveScope
    ) async throws {
        switch scope {
        case .onlyThisTime:
            try await self.googleCalendarUsecase.removeEvent(
                google.calendarId, google.eventIdentifier, accountId: google.accountId, scope: .thisEventOnly
            )
        case .all:
            // 셀의 eventIdentifier 는 펼쳐진 인스턴스 id — 시리즈를 지우려면 마스터 id 가 필요하다
            if let masterId = google.recurringEventId {
                try await self.googleCalendarUsecase.removeEvent(
                    google.calendarId, masterId, accountId: google.accountId, scope: .allEvents
                )
            } else {
                try await self.googleCalendarUsecase.removeEvent(
                    google.calendarId, google.eventIdentifier, accountId: google.accountId, scope: .thisEventOnly
                )
            }
        case .thisAndFuture:
            break
        }
    }

    private func removeAppleEvent(
        _ apple: AppleCalendarEventCellViewModel,
        _ scope: EventListRemoveScope
    ) async throws {
        switch scope {
        case .onlyThisTime:
            try await self.appleCalendarUsecase.removeEvent(apple.eventIdentifier, scope: .thisEventOnly)
        case .thisAndFuture:
            try await self.appleCalendarUsecase.removeEvent(apple.eventIdentifier, scope: .thisAndFuture)
        case .all:
            try await self.appleCalendarUsecase.removeEvent(apple.eventIdentifier, scope: .thisEventOnly)
        }
    }

    private func removeConfirmMessage(_ scope: EventListRemoveScope) -> String {
        switch scope {
        case .onlyThisTime:
            return R.String.calendarEventMoreActionRemoveOnlyThistimeMessage
        case .thisAndFuture:
            return "calendar::event::more_action::remove_this_and_future:message".localized()
        case .all:
            return R.String.calendarEventMoreActionRemoveMessage
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
