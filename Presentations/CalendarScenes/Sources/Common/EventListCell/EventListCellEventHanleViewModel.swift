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
    
    var router: (any EventListCellEventHanleRouting)?
    
    init(
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        foremostEventUsecase: any ForemostEventUsecase
    ) {
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.foremostEventUsecase = foremostEventUsecase
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
                calendarId: google.calendarId, eventId: google.eventIdentifier
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
            
        case .edit:
            self.selectEvent(cellViewModel)
            
        case .skipTodo:
            guard let todo = cellViewModel as? TodoEventCellViewModel else { return }
            self.skipTodoToNext(todo)
            
        case .copy:
            self.copyEvent(cellViewModel)
            
        case .editGoogleEvent(let link):
            self.router?.routeToEditGoogleEvent(link)
        }
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
                _ = try await self?.todoEventUsecase.skipRepeatingTodo(cellViewModel.eventIdentifier, .next)
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
