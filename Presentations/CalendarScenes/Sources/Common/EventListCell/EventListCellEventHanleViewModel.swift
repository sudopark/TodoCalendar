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
import CommonPresentation

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
    private let eventTagUsecase: any EventTagUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let liveActivityToggleViewModel: any LiveActivityToggleViewModel

    var router: (any EventListCellEventHanleRouting)?

    init(
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        appleCalendarUsecase: any AppleCalendarUsecase,
        externalCalendarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        liveActivityToggleViewModel: any LiveActivityToggleViewModel
    ) {
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
        self.appleCalendarUsecase = appleCalendarUsecase
        self.externalCalendarIntegrationUsecase = externalCalendarIntegrationUsecase
        self.eventTagUsecase = eventTagUsecase
        self.eventDetailDataUsecase = eventDetailDataUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
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
        case .remove(let scope):
            self.removeEvent(cellViewModel, scope)
            
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

        case .share:
            self.shareEvent(cellViewModel)
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

    private func shareEvent(_ cellViewModel: any EventCellViewModel) {
        switch cellViewModel {
        case let todo as TodoEventCellViewModel:
            self.shareTodoEvent(todo)
        case let schedule as ScheduleEventCellViewModel:
            self.shareScheduleEvent(schedule)
        case let google as GoogleCalendarEventCellViewModel:
            self.shareGoogleEvent(google)
        case let apple as AppleCalendarEventCellViewModel:
            self.shareAppleEvent(apple)
        default: return
        }
    }

    private func shareTodoEvent(_ cellViewModel: TodoEventCellViewModel) {
        self.todoEventUsecase.todoEvent(cellViewModel.eventIdentifier)
            .first()
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                self?.router?.showError(error)
            }, receiveValue: { [weak self] todo in
                self?.assembleAndShareText(
                    name: todo.name, isTodo: true,
                    time: todo.time, repeating: todo.repeating,
                    eventTagId: todo.eventTagId ?? .default, detailId: todo.uuid
                )
            })
            .store(in: &self.cancellables)
    }

    private func shareScheduleEvent(_ cellViewModel: ScheduleEventCellViewModel) {
        self.scheduleEventUsecase.scheduleEvent(cellViewModel.eventIdWithoutTurn)
            .first()
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                self?.router?.showError(error)
            }, receiveValue: { [weak self] schedule in
                let eventTime = cellViewModel.eventTimeRawValue ?? schedule.time
                self?.assembleAndShareText(
                    name: schedule.name, isTodo: false,
                    time: eventTime, repeating: schedule.repeating,
                    eventTagId: schedule.eventTagId ?? .default, detailId: schedule.uuid
                )
            })
            .store(in: &self.cancellables)
    }

    private func assembleAndShareText(
        name: String, isTodo: Bool,
        time: EventTime?, repeating: EventRepeating?,
        eventTagId: EventTagId, detailId: String
    ) {
        let builder = EventDetailShareTextBuilder()
        Publishers.CombineLatest3(
            self.eventTagUsecase.eventTag(id: eventTagId),
            self.eventDetailDataUsecase.loadDetail(detailId)
                .map { $0 as EventDetailData? }
                .catch { _ in Just(nil) }
                .replaceEmpty(with: nil),
            self.calendarSettingUsecase.currentTimeZone.first()
        )
        .first()
        .sink { [weak self] tag, detail, timeZone in
            let timeText = time.map { SelectedTime($0, timeZone) }.map(builder.timeText(from:))
            let repeatSummaryText = repeating.flatMap { repeating -> String? in
                guard let repeatStart = time.map({ Date(timeIntervalSince1970: $0.lowerBoundWithFixed) })
                else { return nil }
                return repeating.repeatOption.summaryText(startTime: repeatStart, timeZone: timeZone)
            }
            let model = EventDetailShareModel(
                name: name,
                isTodo: isTodo,
                timeText: timeText,
                repeatText: repeatSummaryText?.emptyAsNil(),
                tagLine: tag?.name.emptyAsNil().map { .eventTag($0) },
                placeName: detail?.place?.placeName.emptyAsNil(),
                url: detail?.url?.emptyAsNil(),
                memo: detail?.memo?.emptyAsNil()
            )
            self?.showShareSheetIfNeeded(model, builder)
        }
        .store(in: &self.cancellables)
    }

    private func shareGoogleEvent(_ cellViewModel: GoogleCalendarEventCellViewModel) {
        let calendarId = cellViewModel.calendarId
        let accountId = cellViewModel.accountId
        let eventId = cellViewModel.eventIdentifier
        self.calendarSettingUsecase.currentTimeZone
            .first()
            .setFailureType(to: (any Error).self)
            .flatMap { [weak self] timeZone -> AnyPublisher<(GoogleCalendar.EventOrigin, [GoogleCalendar.Tag], TimeZone), any Error> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return Publishers.CombineLatest(
                    self.googleCalendarUsecase.eventDetail(calendarId, eventId, accountId: accountId, at: timeZone),
                    self.googleCalendarUsecase.calendarTags.setFailureType(to: (any Error).self)
                )
                .map { origin, tags in (origin, tags, timeZone) }
                .eraseToAnyPublisher()
            }
            .first()
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                self?.router?.showError(error)
            }, receiveValue: { [weak self] origin, tags, timeZone in
                self?.shareGoogleEventText(origin, calendarId: calendarId, tags: tags, timeZone: timeZone)
            })
            .store(in: &self.cancellables)
    }

    private func shareGoogleEventText(
        _ origin: GoogleCalendar.EventOrigin,
        calendarId: String,
        tags: [GoogleCalendar.Tag],
        timeZone: TimeZone
    ) {
        let builder = EventDetailShareTextBuilder()
        let selectedTime = origin.selectedTime(timeZone)
        let repeatText = origin.shareRepeatText(timeZone)
        let tagLine = tags.first(where: { $0.id == calendarId })?.name.emptyAsNil()
            .map { EventDetailShareTagLine.googleCalendar($0) }
        let model = EventDetailShareModel(
            name: origin.summaryText,
            isTodo: false,
            timeText: selectedTime.map(builder.timeText(from:)),
            repeatText: repeatText,
            tagLine: tagLine,
            placeName: origin.location?.emptyAsNil(),
            url: nil,
            memo: origin.description.asPlainShareText
        )
        self.showShareSheetIfNeeded(model, builder)
    }

    private func shareAppleEvent(_ cellViewModel: AppleCalendarEventCellViewModel) {
        let calendarId = cellViewModel.calendarId
        Publishers.CombineLatest3(
            self.appleCalendarUsecase.eventOrigin(id: cellViewModel.eventIdentifier),
            self.appleCalendarUsecase.calendarTags,
            self.calendarSettingUsecase.currentTimeZone
        )
        .first()
        .sink { [weak self] origin, tags, timeZone in
            guard let origin else { return }
            self?.shareAppleEventText(origin, calendarId: calendarId, tags: tags, timeZone: timeZone)
        }
        .store(in: &self.cancellables)
    }

    private func shareAppleEventText(
        _ origin: AppleCalendar.EventOrigin,
        calendarId: String,
        tags: [AppleCalendar.Tag],
        timeZone: TimeZone
    ) {
        let builder = EventDetailShareTextBuilder()
        let selectedTime = SelectedTime(origin.eventTime, timeZone)
        let repeatText = origin.shareRepeatText(timeZone)
        let tagLine = tags.first(where: { $0.id == calendarId })?.name.emptyAsNil()
            .map { EventDetailShareTagLine.appleCalendar($0) }
        let model = EventDetailShareModel(
            name: origin.name,
            isTodo: false,
            timeText: builder.timeText(from: selectedTime),
            repeatText: repeatText,
            tagLine: tagLine,
            placeName: origin.location?.emptyAsNil(),
            url: origin.url?.emptyAsNil(),
            memo: origin.notes?.emptyAsNil()
        )
        self.showShareSheetIfNeeded(model, builder)
    }

    private func showShareSheetIfNeeded(
        _ model: EventDetailShareModel, _ builder: EventDetailShareTextBuilder
    ) {
        let text = builder.build(model)
        guard !text.isEmpty else { return }
        self.router?.showShareSheet(text: text)
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
