//
//  GoogleCalendarEventEditViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes


// MARK: - GoogleCalendarEventEditViewModel

protocol GoogleCalendarEventEditViewModel: AnyObject, Sendable, GoogleCalendarEventEditSceneInteractor {

    // interactor
    func prepare()
    func enter(name: String)
    func selectStartTime(_ date: Date)
    func selectEndTime(_ date: Date)
    func toggleAllDay()
    func enter(location: String?)
    func enter(memo: String?)
    func select(colorId: String?)
    func save()
    func remove()
    func editOnGoogleCalendar()
    func close()

    // presenter
    var eventName: AnyPublisher<String, Never> { get }
    var hasDetailLink: AnyPublisher<Bool, Never> { get }
    var selectedTime: AnyPublisher<SelectedTime?, Never> { get }
    var location: AnyPublisher<String?, Never> { get }
    var memo: AnyPublisher<String?, Never> { get }
    var selectedColorModel: AnyPublisher<GoogleCalendarEventColorModel, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
    var hasChanges: AnyPublisher<Bool, Never> { get }
}


// MARK: - EditableFields

private struct EditableFields: Equatable {
    var name: String
    var time: SelectedTime?
    var location: String?
    var memo: String?
    var colorId: String?
}


// MARK: - GoogleCalendarEventEditViewModelImple

final class GoogleCalendarEventEditViewModelImple: GoogleCalendarEventEditViewModel, @unchecked Sendable {

    private let calendarId: String
    private let accountId: String
    private let eventId: String
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    var router: (any GoogleCalendarEventEditRouting)?
    weak var listener: (any GoogleCalendarEventEditSceneListener)?

    init(
        calendarId: String,
        accountId: String,
        eventId: String,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.calendarId = calendarId
        self.accountId = accountId
        self.eventId = eventId
        self.googleCalendarUsecase = googleCalendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase

        self.internalBind()
    }

    private struct Subject {
        typealias Fields = OriginalAndCurrent<EditableFields>
        let origin = CurrentValueSubject<GoogleCalendar.EventOrigin?, Never>(nil)
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let fields = CurrentValueSubject<Fields?, Never>(nil)
        let isSaving = CurrentValueSubject<Bool, Never>(false)
    }

    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()

    private func internalBind() {
        self.calendarSettingUsecase.currentTimeZone
            .sink(receiveValue: { [weak self] timeZone in
                self?.subject.timeZone.send(timeZone)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - GoogleCalendarEventEditViewModelImple Interactor

extension GoogleCalendarEventEditViewModelImple {

    func prepare() {
        let currentTimeZone = self.subject.timeZone.compactMap { $0 }.first()
        let eventOrigin = currentTimeZone
            .flatMap { [weak self] timeZone -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.googleCalendarUsecase.eventDetail(
                    self.calendarId, self.eventId, accountId: self.accountId, at: timeZone
                )
            }
        eventOrigin
            .sink(receiveValue: { [weak self] origin in
                self?.applyLoaded(origin)
            }, receiveError: { [weak self] error in
                self?.router?.showError(error)
            })
            .store(in: &self.cancellables)
    }

    private func applyLoaded(_ origin: GoogleCalendar.EventOrigin) {
        guard let timeZone = self.subject.timeZone.value else { return }
        self.subject.origin.send(origin)
        let fields = EditableFields(
            name: origin.summaryText,
            time: origin.selectedTime(timeZone),
            location: origin.location,
            memo: origin.description,
            colorId: origin.colorId
        )
        self.subject.fields.send(.init(origin: fields))
    }

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

    func enter(memo: String?) {
        self.updateCurrentFields { $0 |> \.memo .~ memo }
    }

    func select(colorId: String?) {
        self.updateCurrentFields { $0 |> \.colorId .~ colorId }
    }

    private func updateCurrentFields(_ mutate: @escaping (EditableFields) -> EditableFields) {
        guard let fields = self.subject.fields.value else { return }
        self.subject.fields.send(
            fields |> \.current %~ mutate
        )
    }

    func save() {
        guard let origin = self.subject.origin.value,
              let timeZone = self.subject.timeZone.value,
              let params = self.editParams(timeZone), !params.isEmpty
        else {
            self.router?.closeScene()
            return
        }

        guard let recurringEventId = origin.recurringEventId else {
            self.updateEvent(origin.id, params, timeZone)
            return
        }
        self.showUpdateScopeActionSheet(origin.id, recurringEventId, params, timeZone)
    }

    private func editParams(_ timeZone: TimeZone) -> GoogleCalendar.EventEditParams? {
        guard let fields = self.subject.fields.value, fields.isChanged else { return nil }

        var params = GoogleCalendar.EventEditParams()
        if fields.origin.name != fields.current.name {
            params.summary = fields.current.name
        }
        if fields.origin.location != fields.current.location {
            params.location = fields.current.location
        }
        if fields.origin.memo != fields.current.memo {
            params.description = fields.current.memo
        }
        if fields.origin.colorId != fields.current.colorId {
            params.colorId = fields.current.colorId
        }
        if fields.origin.time != fields.current.time,
           let pair = fields.current.time?.asGoogleEventTimePair(timeZone) {
            params.start = pair.start
            params.end = pair.end
        }
        return params
    }

    private func showUpdateScopeActionSheet(
        _ instanceEventId: String,
        _ recurringEventId: String,
        _ params: GoogleCalendar.EventEditParams,
        _ timeZone: TimeZone
    ) {
        var form = ActionSheetForm()
            |> \.title .~ pure("eventDetail::gogoleEvent::repeating::title".localized())

        form.actions.append(
            .init("eventDetail::gogoleEvent::repeating::onlyThisTime::button".localized()) { [weak self] in
                self?.updateEvent(instanceEventId, params, timeZone)
            }
        )
        form.actions.append(
            .init("eventDetail::gogoleEvent::repeating::all::button".localized()) { [weak self] in
                self?.updateEvent(recurringEventId, params, timeZone)
            }
        )
        form.actions.append(.init("common.cancel".localized(), style: .cancel))

        self.router?.showActionSheet(form)
    }

    private func updateEvent(
        _ eventId: String, _ params: GoogleCalendar.EventEditParams, _ timeZone: TimeZone
    ) {
        let calendarId = self.calendarId
        let accountId = self.accountId
        self.subject.isSaving.send(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                let updated = try await self.googleCalendarUsecase.updateEvent(
                    calendarId, eventId, accountId: accountId, at: timeZone, params: params
                )
                self.subject.isSaving.send(false)
                self.router?.closeScene(animate: true) { [weak self] in
                    self?.listener?.googleCalendarEvent(didUpdate: updated)
                }
            } catch {
                self.subject.isSaving.send(false)
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }

    func remove() {
        guard let origin = self.subject.origin.value else { return }

        guard let recurringEventId = origin.recurringEventId else {
            self.confirmRemoveEvent(origin.id)
            return
        }
        self.showRemoveScopeActionSheet(origin.id, recurringEventId)
    }

    private func confirmRemoveEvent(_ eventId: String) {
        let confirmed: () -> Void = { [weak self] in self?.removeEvent(eventId) }
        let info = ConfirmDialogInfo()
            |> \.message .~ pure("eventDetail::gogoleEvent::remove::confirm::message".localized())
            |> \.confirmText .~ "common.remove".localized()
            |> \.confirmed .~ pure(confirmed)
            |> \.withCancel .~ true
            |> \.cancelText .~ "common.cancel".localized()
        self.router?.showConfirm(dialog: info)
    }

    private func showRemoveScopeActionSheet(
        _ instanceEventId: String, _ recurringEventId: String
    ) {
        var form = ActionSheetForm()
            |> \.title .~ pure("eventDetail::gogoleEvent::repeating::title".localized())
            |> \.message .~ pure("eventDetail::gogoleEvent::remove::confirm::message".localized())

        form.actions.append(
            .init(
                "eventDetail::gogoleEvent::repeating::onlyThisTime::button".localized(),
                style: .destructive
            ) { [weak self] in
                self?.removeEvent(instanceEventId)
            }
        )
        form.actions.append(
            .init(
                "eventDetail::gogoleEvent::repeating::all::button".localized(),
                style: .destructive
            ) { [weak self] in
                self?.removeEvent(recurringEventId)
            }
        )
        form.actions.append(.init("common.cancel".localized(), style: .cancel))

        self.router?.showActionSheet(form)
    }

    private func removeEvent(_ eventId: String) {
        let calendarId = self.calendarId
        let accountId = self.accountId
        self.subject.isSaving.send(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.googleCalendarUsecase.removeEvent(calendarId, eventId, accountId: accountId)
                self.subject.isSaving.send(false)
                self.router?.closeScene(animate: true) { [weak self] in
                    self?.listener?.googleCalendarEvent(didRemove: eventId)
                }
            } catch {
                self.subject.isSaving.send(false)
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }

    func editOnGoogleCalendar() {
        guard let link = self.subject.origin.value?.htmlLink else { return }
        self.router?.openSafari(link)
    }

    func close() {
        self.router?.closeScene()
    }
}


// MARK: - GoogleCalendarEventEditViewModelImple Presenter

extension GoogleCalendarEventEditViewModelImple {

    var eventName: AnyPublisher<String, Never> {
        self.subject.fields
            .compactMap { $0?.current.name }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var selectedTime: AnyPublisher<SelectedTime?, Never> {
        self.subject.fields
            .map { $0?.current.time }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var location: AnyPublisher<String?, Never> {
        self.subject.fields
            .map { $0?.current.location }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var memo: AnyPublisher<String?, Never> {
        self.subject.fields
            .map { $0?.current.memo }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var selectedColorModel: AnyPublisher<GoogleCalendarEventColorModel, Never> {
        let calendarId = self.calendarId
        return self.subject.fields
            .compactMap { $0 }
            .map { GoogleCalendarEventColorModel(colorId: $0.current.colorId, calendarId: calendarId) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var isSavable: AnyPublisher<Bool, Never> {
        self.subject.fields
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
        self.subject.isSaving
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var hasChanges: AnyPublisher<Bool, Never> {
        self.subject.fields
            .map { $0?.isChanged ?? false }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var hasDetailLink: AnyPublisher<Bool, Never> {
        self.subject.origin
            .map { $0?.htmlLink != nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}


// MARK: - GoogleCalendar time <-> SelectedTime mapping

private extension GoogleCalendar.EventOrigin {

    func selectedTime(_ timeZone: TimeZone) -> SelectedTime? {
        let start = self.start?.supportEventTimeElemnt(timeZone.identifier)
        let end = self.end?.supportEventTimeElemnt(timeZone.identifier)
        switch (start, end) {
        case (.period(let st), .period(let et)):
            return SelectedTime(
                .period(st.timeIntervalSince1970..<et.timeIntervalSince1970), timeZone
            )
        case (.allDay(let st, let sz), .allDay(let et, _)):
            return SelectedTime(
                .allDay(
                    st.timeIntervalSince1970..<et.timeIntervalSince1970,
                    secondsFromGMT: TimeInterval(sz.secondsFromGMT())
                ),
                timeZone
            )
        default:
            return nil
        }
    }
}

private extension SelectedTime {

    // 읽기(EventOrigin.selectedTime)가 구글의 배타적 end.date를 가공 없이 담으므로, 왕복 항등을 위해 여기도 가공하지 않는다.
    func asGoogleEventTimePair(
        _ timeZone: TimeZone
    ) -> (start: GoogleCalendar.EventOrigin.GoogleEventTime, end: GoogleCalendar.EventOrigin.GoogleEventTime)? {
        switch self {
        case .at:
            return nil

        case .period(let start, let end):
            guard start.date < end.date else { return nil }
            return (
                .init(dateTime: start.date.timeIntervalSince1970, timeZone),
                .init(dateTime: end.date.timeIntervalSince1970, timeZone)
            )

        case .singleAllDay(let day):
            let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day.date)
            else { return nil }
            return (
                .init(date: day.date.timeIntervalSince1970, timeZone),
                .init(date: nextDay.timeIntervalSince1970, timeZone)
            )

        case .alldayPeriod(let start, let end):
            guard start.date < end.date else { return nil }
            return (
                .init(date: start.date.timeIntervalSince1970, timeZone),
                .init(date: end.date.timeIntervalSince1970, timeZone)
            )
        }
    }
}

private extension GoogleCalendar.EventOrigin.GoogleEventTime {

    init(dateTime timeStamp: TimeInterval, _ timeZone: TimeZone) {
        self.init()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        self.dateTime = formatter.string(from: Date(timeIntervalSince1970: timeStamp))
        self.timeZone = timeZone.identifier
    }

    init(date timeStamp: TimeInterval, _ timeZone: TimeZone) {
        self.init()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        self.date = formatter.string(from: Date(timeIntervalSince1970: timeStamp))
    }
}
