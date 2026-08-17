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
import Extensions
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
    func close()
    func enter(name: String)
    func selectStartTime(_ date: Date)
    func selectEndTime(_ date: Date)
    func toggleAllDay()
    func enter(location: String?)
    func enter(url: String?)
    func enter(notes: String?)
    func save()
    func remove()
    func selectNotEditableField()

    // presenter
    var isEditable: AnyPublisher<Bool, Never> { get }
    var readOnlyCalendarMessage: AnyPublisher<String?, Never> { get }
    var eventName: AnyPublisher<String, Never> { get }
    var timeText: AnyPublisher<SelectedTime?, Never> { get }
    var ddayText: AnyPublisher<String, Never> { get }
    var repeatText: AnyPublisher<String?, Never> { get }
    var location: AnyPublisher<String?, Never> { get }
    var url: AnyPublisher<String?, Never> { get }
    var notes: AnyPublisher<String?, Never> { get }
    var attendees: AnyPublisher<[AppleCalendar.Attendee], Never> { get }
    var tagModel: AnyPublisher<AppleCalendarTagModel?, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
}


// MARK: - EditableFields

private struct EditableFields: Equatable {
    var name: String
    var time: SelectedTime?
    var location: String?
    var url: String?
    var notes: String?
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
        let fields = CurrentValueSubject<OriginalAndCurrent<EditableFields>?, Never>(nil)
        let isSaving = CurrentValueSubject<Bool, Never>(false)
        let isWritable = CurrentValueSubject<Bool?, Never>(nil)
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

        self.appleCalendarUsecase.isCalendarWritable(calendarId)
            .sink { [weak self] isWritable in
                self?.subject.isWritable.send(isWritable)
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
                self?.applyLoaded(origin)
            }
            .store(in: &self.cancellables)
    }

    private func applyLoaded(_ origin: AppleCalendar.EventOrigin) {
        guard self.subject.fields.value?.isChanged != true else { return }
        guard let timeZone = self.subject.timeZone.value else { return }
        self.subject.event.send(origin)
        let fields = EditableFields(
            name: origin.name,
            time: SelectedTime(origin.eventTime, timeZone),
            location: origin.location,
            url: origin.url.flatMap { $0.isEmpty ? nil : $0 },
            notes: origin.notes
        )
        self.subject.fields.send(.init(origin: fields))
    }

    func openInAppleCalendar() {
        guard let origin = self.subject.event.value else { return }
        let startInterval = origin.eventTime.lowerBoundWithFixed
        self.router?.routeToAppleCalendarApp(at: startInterval)
    }

    func close() {
        self.router?.closeScene()
    }

    func selectNotEditableField() {
        self.router?.showToast("eventDetail::appleCalendarEvent::notEditableField::message".localized())
    }
}


// MARK: - AppleCalendarEventDetailViewModelImple Editable Fields Interactor

extension AppleCalendarEventDetailViewModelImple {

    func enter(name: String) {
        self.updateCurrentFields { $0 |> \.name .~ name }
    }

    func selectStartTime(_ date: Date) {
        guard let timeZone = self.subject.timeZone.value else { return }
        self.updateCurrentFields { fields in
            fields |> \.time .~ fields.time.periodStartChanged(date, timeZone)
        }
    }

    func selectEndTime(_ date: Date) {
        guard let timeZone = self.subject.timeZone.value else { return }
        self.updateCurrentFields { fields in
            fields |> \.time .~ fields.time.periodEndTimeChanged(date, timeZone)
        }
    }

    func toggleAllDay() {
        guard let timeZone = self.subject.timeZone.value else { return }
        self.updateCurrentFields { fields in
            fields |> \.time .~ fields.time?.toggleIsAllDay(timeZone)
        }
    }

    func enter(location: String?) {
        self.updateCurrentFields { $0 |> \.location .~ location }
    }

    func enter(url: String?) {
        self.updateCurrentFields { $0 |> \.url .~ url }
    }

    func enter(notes: String?) {
        self.updateCurrentFields { $0 |> \.notes .~ notes }
    }

    private func updateCurrentFields(_ mutate: @escaping (EditableFields) -> EditableFields) {
        // nil(판정 전)도 막는다 — fail-closed
        guard self.subject.isWritable.value == true else { return }
        guard !self.subject.isSaving.value else { return }
        guard let fields = self.subject.fields.value else { return }
        self.subject.fields.send(
            fields |> \.current %~ mutate
        )
    }
}


// MARK: - AppleCalendarEventDetailViewModelImple Save

extension AppleCalendarEventDetailViewModelImple {

    func save() {
        guard self.subject.isWritable.value == true else { return }
        self.saveChanges()
    }

    private func saveChanges() {
        guard let origin = self.subject.event.value,
              let timeZone = self.subject.timeZone.value,
              let params = self.editParams(timeZone), !params.isEmpty
        else {
            return
        }

        guard origin.isRepeating else {
            self.updateEvent(origin.eventId, params, scope: .thisEventOnly)
            return
        }
        self.showUpdateScopeActionSheet(origin.eventId, params)
    }

    private func editParams(_ timeZone: TimeZone) -> AppleCalendar.EventEditParams? {
        guard let fields = self.subject.fields.value, fields.isChanged else { return nil }

        var params = AppleCalendar.EventEditParams()
        if fields.origin.name != fields.current.name {
            params.name = fields.current.name
        }
        if fields.origin.location != fields.current.location {
            params.location = fields.current.location
        }
        if fields.origin.url != fields.current.url {
            params.url = fields.current.url
        }
        if fields.origin.notes != fields.current.notes {
            params.notes = fields.current.notes
        }
        if fields.origin.time != fields.current.time {
            params.time = fields.current.time?.eventTime(timeZone)
        }
        return params
    }

    private func showUpdateScopeActionSheet(
        _ eventId: String, _ params: AppleCalendar.EventEditParams
    ) {
        var form = ActionSheetForm()
            |> \.title .~ pure("eventDetail::appleCalendarEvent::repeating::title".localized())

        form.actions.append(
            .init("eventDetail::appleCalendarEvent::repeating::onlyThisTime::button".localized()) { [weak self] in
                self?.updateEvent(eventId, params, scope: .thisEventOnly)
            }
        )
        form.actions.append(
            .init("eventDetail::appleCalendarEvent::repeating::thisAndFuture::button".localized()) { [weak self] in
                self?.updateEvent(eventId, params, scope: .thisAndFuture)
            }
        )
        form.actions.append(.init("common.cancel".localized(), style: .cancel))

        self.router?.showActionSheet(form)
    }

    private func updateEvent(
        _ eventId: String, _ params: AppleCalendar.EventEditParams, scope: AppleCalendar.EventEditScope
    ) {
        self.subject.isSaving.send(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.appleCalendarUsecase.updateEvent(eventId, params: params, scope: scope)
                self.subject.isSaving.send(false)
                self.router?.showToast("eventDetail::appleCalendarEvent::saved::message".localized())
                self.router?.closeScene()
            } catch {
                self.subject.isSaving.send(false)
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
}


// MARK: - AppleCalendarEventDetailViewModelImple Remove

extension AppleCalendarEventDetailViewModelImple {

    func remove() {
        guard self.subject.isWritable.value == true else { return }
        self.removeWithScope()
    }

    private func removeWithScope() {
        guard let origin = self.subject.event.value else { return }

        guard origin.isRepeating else {
            self.confirmRemoveEvent(origin.eventId)
            return
        }
        self.showRemoveScopeActionSheet(origin.eventId)
    }

    private func confirmRemoveEvent(_ eventId: String) {
        let confirmed: () -> Void = { [weak self] in self?.removeEvent(eventId, scope: .thisEventOnly) }
        let info = ConfirmDialogInfo()
            |> \.message .~ pure("eventDetail::appleCalendarEvent::remove::confirm::message".localized())
            |> \.confirmText .~ "common.remove".localized()
            |> \.confirmed .~ pure(confirmed)
            |> \.withCancel .~ true
            |> \.cancelText .~ "common.cancel".localized()
        self.router?.showConfirm(dialog: info)
    }

    private func showRemoveScopeActionSheet(_ eventId: String) {
        var form = ActionSheetForm()
            |> \.title .~ pure("eventDetail::appleCalendarEvent::repeating::title".localized())
            |> \.message .~ pure("eventDetail::appleCalendarEvent::remove::confirm::message".localized())

        form.actions.append(
            .init(
                "eventDetail::appleCalendarEvent::repeating::onlyThisTime::button".localized(),
                style: .destructive
            ) { [weak self] in
                self?.removeEvent(eventId, scope: .thisEventOnly)
            }
        )
        form.actions.append(
            .init(
                "eventDetail::appleCalendarEvent::repeating::thisAndFuture::button".localized(),
                style: .destructive
            ) { [weak self] in
                self?.removeEvent(eventId, scope: .thisAndFuture)
            }
        )
        form.actions.append(.init("common.cancel".localized(), style: .cancel))

        self.router?.showActionSheet(form)
    }

    private func removeEvent(_ eventId: String, scope: AppleCalendar.EventEditScope) {
        self.subject.isSaving.send(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.appleCalendarUsecase.removeEvent(eventId, scope: scope)
                self.subject.isSaving.send(false)
                self.router?.closeScene()
            } catch {
                self.subject.isSaving.send(false)
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
}


// MARK: - AppleCalendarEventDetailViewModelImple Presenter

extension AppleCalendarEventDetailViewModelImple {

    var isEditable: AnyPublisher<Bool, Never> {
        return self.subject.isWritable
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var readOnlyCalendarMessage: AnyPublisher<String?, Never> {
        return self.subject.isWritable
            .compactMap { $0 }
            .map { isWritable -> String? in
                guard !isWritable else { return nil }
                return "eventDetail::appleCalendarEvent::readOnlyCalendar::message".localized()
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var eventName: AnyPublisher<String, Never> {
        return self.subject.fields
            .compactMap { $0?.current.name }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var timeText: AnyPublisher<SelectedTime?, Never> {
        return self.subject.fields
            .compactMap { $0 }
            .map { $0.current.time }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var ddayText: AnyPublisher<String, Never> {
        let countDays: (SelectedTime, TimeZone) -> AnyPublisher<Int, Never> = { [weak self] time, timeZone in
            guard let self, let eventTime = time.eventTime(timeZone) else { return Empty().eraseToAnyPublisher() }
            return self.daysIntervalCountUsecase.countDays(to: eventTime)
        }

        return Publishers.CombineLatest(
            self.subject.fields.compactMap { $0?.current.time },
            self.subject.timeZone.compactMap { $0 }
        )
        .map(countDays)
        .switchToLatest()
        .removeDuplicates()
        .map { DDayText($0).text }
        .eraseToAnyPublisher()
    }

    var location: AnyPublisher<String?, Never> {
        return self.subject.fields
            .compactMap { $0 }
            .map { $0.current.location }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var repeatText: AnyPublisher<String?, Never> {
        return Publishers.CombineLatest(
            self.subject.event.compactMap { $0 },
            self.subject.timeZone.compactMap { $0 }
        )
        .map { event, timeZone -> String? in
            guard let rruleString = event.recurrenceRules.first,
                  let rrule = RRuleParser.parse(rruleString) else { return nil }
            let frequencyText = rrule.frequencyText()
            if let endText = rrule.endOptionText(timeZone) {
                return "\(frequencyText) \(endText)"
            }
            return frequencyText
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var url: AnyPublisher<String?, Never> {
        return self.subject.fields
            .compactMap { $0 }
            .map { $0.current.url }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var notes: AnyPublisher<String?, Never> {
        return self.subject.fields
            .compactMap { $0 }
            .map { $0.current.notes }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var attendees: AnyPublisher<[AppleCalendar.Attendee], Never> {
        return self.subject.event
            .compactMap { $0 }
            .map { $0.attendees }
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

    var isSavable: AnyPublisher<Bool, Never> {
        return self.subject.fields
            .map { fields -> Bool in
                guard let fields, fields.isChanged else { return false }
                let nameIsNotEmpty = !fields.current.name.isEmpty
                let timeIsValid = fields.current.time?.isValid ?? false
                return nameIsNotEmpty && timeIsValid
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var isSaving: AnyPublisher<Bool, Never> {
        return self.subject.isSaving
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
