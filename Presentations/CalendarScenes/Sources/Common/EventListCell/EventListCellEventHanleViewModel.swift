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

protocol EventListCellEventHanleViewModel {
    
    func selectEvent(_ model: any EventCellViewModel)
    func doneTodo(_ eventId: String)
    func cancelDoneTodo(_ eventId: String)
    func handleMoreAction(
        _ cellViewModel: any EventCellViewModel,
        _ action: EventListMoreAction
    )
    
    var doneTodoResult: AnyPublisher<DoneTodoResult, Never> { get }
}


final class EventListCellEventHanleViewModelImple: EventListCellEventHanleViewModel {
    
    private let todoEventUsecase: any TodoEventUsecase
    private let scheduleEventUsecase: any ScheduleEventUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    
    var router: (any EventListCellEventHanleRouting)?
    
    init(todoEventUsecase: any TodoEventUsecase, scheduleEventUsecase: any ScheduleEventUsecase, foremostEventUsecase: any ForemostEventUsecase) {
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
        // TODO: show detail
        switch model {
        case let todo as TodoEventCellViewModel:
            self.router?.routeToTodoEventDetail(todo.eventIdentifier)
        case let schedule as ScheduleEventCellViewModel:
            self.router?.routeToScheduleEventDetail(schedule.eventIdWithoutTurn)
        case let holiday as HolidayEventCellViewModel:
            // TODO:
            break
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
        
        self.runMoreActionAfterConfirm(
            action.confirmTitle,
            action.confirmMessage
        ) { [weak self] in
            
            guard let self = self else { return }
            
            Task { [weak self] in
                do {
                    switch action {
                    case .remove(let onlyThisTime):
                        try await self?.removeEvent(cellViewModel, onlyThisTime)
                    case .toggleTo(let isForemost):
                        try await self?.toggleForemostEvent(cellViewModel, isForemost)
                    }
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
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
    
    private func removeEvent(
        _ cellViewModel: any EventCellViewModel,
        _ onlyThisTime: Bool
    ) async throws {
        switch cellViewModel {
        case let todo as TodoEventCellViewModel:
            try await self.todoEventUsecase.removeTodo(
                todo.eventIdentifier, onlyThisTime: onlyThisTime
            )
        case let schedule as ScheduleEventCellViewModel:
            let time = onlyThisTime ? schedule.eventTimeRawValue : nil
            try await self.scheduleEventUsecase.removeScheduleEvent(
                schedule.eventIdWithoutTurn, onlyThisTime: time
            )
        default: break
        }
    }
    
    private func toggleForemostEvent(
        _ cellViewModel: any EventCellViewModel,
        _ newValue: Bool
    ) async throws {
        switch (cellViewModel, newValue) {
        case (_, false):
            try await self.foremostEventUsecase.remove()
        case (let todo as TodoEventCellViewModel, _):
            try await self.foremostEventUsecase.update(
                foremost: .init(todo.eventIdentifier, true)
            )
        case (let schedule as ScheduleEventCellViewModel, _):
            try await self.foremostEventUsecase.update(
                foremost: .init(schedule.eventIdWithoutTurn, false)
            )
        default: break
        }
    }
}

extension EventListCellEventHanleViewModelImple {
    
    var doneTodoResult: AnyPublisher<DoneTodoResult, Never> {
        return self.subject.doneTodoResult
            .eraseToAnyPublisher()
    }
}

private extension EventListMoreAction {
    
    var confirmTitle: String {
        switch self {
        case .remove: return "remove event".localized()
        case .toggleTo: return "foremost event".localized()
        }
    }
    
    var confirmMessage: String {
        switch self {
        case .remove(let onlyThisTime) where onlyThisTime:
            return "remove only this time message".localized()
        case .remove:
            return "remove event message".localized()
        case .toggleTo(let isForemost) where isForemost:
            return "register foremost message".localized()
        case .toggleTo:
            return "remove foremost message".localized()
        }
    }
}
