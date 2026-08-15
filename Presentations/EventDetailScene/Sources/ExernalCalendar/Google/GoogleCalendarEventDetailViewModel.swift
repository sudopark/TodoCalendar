//
//  
//  GoogleCalendarEventDetailViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import Foundation
import UIKit
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes


struct AttendeeViewModelModel: Equatable {
    
    var id: String?
    let name: String
    var isOrganizer: Bool = false
    var isAccepted: Bool = false
    
    init(_ id: String, _ name: String) {
        self.id = id
        self.name = name
    }
    
    init(_ attendee: GoogleCalendar.EventOrigin.Attendee) {
        self.id = attendee.identifier
        self.name = attendee.displayNameOrEmail ?? "eventDetail::gogoleEvent::attendee::unknown".localized()
        self.isOrganizer = attendee.organizer ?? false
        self.isAccepted = attendee.isAccepted
    }
}

struct AttendeeListViewModel: Equatable {
    let attendees: [AttendeeViewModelModel]
    let totalCounts: Int
}

struct GoogleCalendarModel: Equatable {
    let calenarId: String
    let name: String
}

struct GoogleCalendarEventColorModel: Equatable {
    let colorId: String?
    let calendarId: String
}

struct AttachmentModel: Equatable {
    let id: String
    let fileURL: String
    let title: String
    var iconLink: String?
}


struct ConferenceEntryModel: Equatable {
    let uri: String
    
    var entryCodeKey: String?
    var entryCodeValue: String?
    
    init(uri: String) {
        self.uri = uri
    }
    
    init?(_ entry: GoogleCalendar.EventOrigin.ConferenceData.EntryPoint) {
        guard let uri = entry.uri
        else { return nil }
        self.uri = uri
        if let code = entry.accessCode {
            self.entryCodeKey = "eventDetail::gogoleEvent::conference::accessCode".localized()
            self.entryCodeValue = code
        } else if let code = entry.meetingCode {
            self.entryCodeKey = "eventDetail::gogoleEvent::conference::meetingCode".localized()
            self.entryCodeValue = code
        } else if let code = entry.passcode {
            self.entryCodeKey = "eventDetail::gogoleEvent::conference::passCode".localized()
            self.entryCodeValue = code
        } else if let code = entry.passcode {
            self.entryCodeKey = "eventDetail::gogoleEvent::conference::password".localized()
            self.entryCodeValue = code
        }
    }
}

struct ConferenceModel: Equatable {
    
    let iconURL: String
    let name: String
    let entries: [ConferenceEntryModel]
    
    init(iconURL: String, name: String, entries: [ConferenceEntryModel]) {
        self.iconURL = iconURL
        self.name = name
        self.entries = entries
    }
    
    init?(_ data: GoogleCalendar.EventOrigin.ConferenceData) {
        guard let icon = data.conferenceSolution?.iconUri,
              let name = data.conferenceSolution?.name
        else { return nil }
        self.iconURL = icon
        self.name = name
        self.entries = data.entryPoints?.compactMap { .init($0) } ?? []
    }
}

// MARK: - GoogleCalendarEventDetailViewModel

protocol GoogleCalendarEventDetailViewModel: AnyObject, Sendable, GoogleCalendarEventDetailSceneInteractor {

    // interactor
    func refresh()
    func editEvent()
    func viewOnGoogleCalendar()
    func selectLink(_ link: URL)
    func selectAttachment(_ model: AttachmentModel)
    func copyText(_ text: String)
    func close()
    func enter(name: String)
    func selectStartTime(_ date: Date)
    func selectEndTime(_ date: Date)
    func toggleAllDay()
    func enter(location: String?)
    func enter(memo: String?)
    func select(colorId: String?)

    // presenter
    var isEditable: AnyPublisher<Bool, Never> { get }
    var readOnlyCalendarMessage: AnyPublisher<String?, Never> { get }
    var hasDetailLink: AnyPublisher<Bool, Never> { get }
    var eventColorModel: AnyPublisher<GoogleCalendarEventColorModel, Never> { get }
    var eventName: AnyPublisher<String, Never> { get }
    var timeText: AnyPublisher<SelectedTime?, Never> { get }
    var ddayText: AnyPublisher<String, Never> { get }
    var repeatOption: AnyPublisher<String?, Never> { get }
    var calendarModel: AnyPublisher<GoogleCalendarModel?, Never> { get }
    var location: AnyPublisher<String?, Never> { get }
    var conferenceModel: AnyPublisher<ConferenceModel?, Never> { get }
    var attendees: AnyPublisher<AttendeeListViewModel?, Never> { get }
    // 회의 모델
    var descriptionHTMLText: AnyPublisher<String?, Never> { get }
    var attachments: AnyPublisher<[AttachmentModel]?, Never> { get }
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


// MARK: - GoogleCalendarEventDetailViewModelImple

final class GoogleCalendarEventDetailViewModelImple: GoogleCalendarEventDetailViewModel, @unchecked Sendable {

    private let calendarId: String
    private let accountId: String
    private let eventId: String
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let externalCalendarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    private let daysIntervalCountUsecase: any DaysIntervalCountUsecase
    var router: (any GoogleCalendarEventDetailRouting)?

    init(
        calenadrId: String,
        accountId: String,
        eventId: String,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        externalCalendarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        daysIntervalCountUsecase: any DaysIntervalCountUsecase
    ) {
        self.calendarId = calenadrId
        self.accountId = accountId
        self.eventId = eventId
        self.googleCalendarUsecase = googleCalendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.externalCalendarIntegrationUsecase = externalCalendarIntegrationUsecase
        self.daysIntervalCountUsecase = daysIntervalCountUsecase

        self.internalBind()
    }


    private struct Subject {
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let origin = CurrentValueSubject<GoogleCalendar.EventOrigin?, Never>(nil)
        let calendarTag = CurrentValueSubject<GoogleCalendar.Tag?, Never>(nil)
        let writePermission = CurrentValueSubject<GoogleCalendar.EventWritePermission?, Never>(nil)
        let fields = CurrentValueSubject<OriginalAndCurrent<EditableFields>?, Never>(nil)
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
        
        let calendarId = self.calendarId
        self.googleCalendarUsecase.calendarTags
            .map { cs in cs.first(where: { $0.id == calendarId}) }
            .sink(receiveValue: { [weak self] tag in
                self?.subject.calendarTag.send(tag)
            })
            .store(in: &self.cancellables)

        self.googleCalendarUsecase.eventWritePermission(
            accountId: self.accountId, calendarId: self.calendarId
        )
        .sink(receiveValue: { [weak self] permission in
            self?.subject.writePermission.send(permission)
        })
        .store(in: &self.cancellables)
    }
}


// MARK: - GoogleCalendarEventDetailViewModelImple Interactor

extension GoogleCalendarEventDetailViewModelImple {
    
    func refresh() {
        
        let currentTimeZone = self.subject.timeZone.compactMap { $0 }.first()
        let eventOrigin = currentTimeZone.flatMap { [weak self] timeZone -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.googleCalendarUsecase.eventDetail(self.calendarId, self.eventId, accountId: self.accountId, at: timeZone).eraseToAnyPublisher()
        }
        eventOrigin
            .sink(receiveValue: { [weak self] event in
                if event.status == .cancelled {
                    self?.alertEventCanceled()
                    return
                }
                self?.applyLoaded(event)
            }, receiveError: { [weak self] error in
                self?.router?.showError(error)
            })
            .store(in: &self.cancellables)
    }

    private func alertEventCanceled() {
        self.router?.showToast("eventDetail::gogoleEvent::canceled::message".localized())
        self.router?.closeScene()
    }

    private func applyLoaded(_ event: GoogleCalendar.EventOrigin) {
        guard self.subject.fields.value?.isChanged != true else { return }
        guard let timeZone = self.subject.timeZone.value else { return }
        self.subject.origin.send(event)
        let fields = EditableFields(
            name: event.summaryText,
            time: event.selectedTime(timeZone),
            location: event.location,
            memo: event.description,
            colorId: event.colorId
        )
        self.subject.fields.send(.init(origin: fields))
    }

    func editEvent() {

        switch self.subject.writePermission.value {
        case .writable:
            self.routeToEditScene()
        case .needReauthentication:
            self.confirmReauthenticationForEdit()
        case .readOnlyCalendar, .none:
            return
        }
    }

    private func routeToEditScene() {
        self.router?.routeToEditEvent(
            calendarId: self.calendarId, accountId: self.accountId, eventId: self.eventId,
            listener: self
        )
    }

    private func confirmReauthenticationForEdit() {
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("eventDetail::gogoleEvent::reauthenticate::title".localized())
            |> \.message .~ pure("eventDetail::gogoleEvent::reauthenticate::message".localized())
            |> \.confirmed .~ pure(self.reauthenticateThenRouteToEditScene)
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }

    private func reauthenticateThenRouteToEditScene() {
        let service = self.googleCalendarUsecase.googleService
        let accountId = self.accountId
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.externalCalendarIntegrationUsecase.reauthenticate(
                    external: service, accountId: accountId
                )
                self.routeToEditScene()
            } catch {
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    func viewOnGoogleCalendar() {
        guard let link = self.subject.origin.value?.htmlLink else { return }
        self.router?.openSafari(link)
    }

    func selectLink(_ link: URL) {
        self.router?.openSafari(link.absoluteString)
    }
    
    func selectAttachment(_ model: AttachmentModel) {
        self.router?.openSafari(model.fileURL)
    }
    
    func copyText(_ text: String) {
        UIPasteboard.general.string = text
        self.router?.showToast(
            "eventDetail::gogoleEvent::copy::message".localized()
        )
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - GoogleCalendarEventDetailViewModelImple Editable Fields Interactor

extension GoogleCalendarEventDetailViewModelImple {

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
}


// MARK: - GoogleCalendarEventDetailViewModelImple Presenter

extension GoogleCalendarEventDetailViewModelImple {
    
    var isEditable: AnyPublisher<Bool, Never> {
        return self.subject.writePermission
            .compactMap { $0 }
            .map { $0 != .readOnlyCalendar }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var readOnlyCalendarMessage: AnyPublisher<String?, Never> {
        return self.subject.writePermission
            .compactMap { $0 }
            .map { permission -> String? in
                guard permission == .readOnlyCalendar else { return nil }
                return "eventDetail::gogoleEvent::readOnlyCalendar::message".localized()
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var hasDetailLink: AnyPublisher<Bool, Never> {
        return self.subject.origin
            .compactMap { $0 }
            .map { $0.htmlLink != nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var eventColorModel: AnyPublisher<GoogleCalendarEventColorModel, Never> {
        let calendarId = self.calendarId
        return self.subject.fields
            .compactMap { $0 }
            .map { GoogleCalendarEventColorModel(colorId: $0.current.colorId, calendarId: calendarId) }
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
        return self.subject.fields
            .compactMap { $0?.current.time }
            .map { [weak self] time -> AnyPublisher<Int, Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.daysIntervalCountUsecase.countDays(to: time.startDate)
            }
            .switchToLatest()
            .removeDuplicates()
            .map { DDayText($0).text }
            .eraseToAnyPublisher()
    }
    
    var repeatOption: AnyPublisher<String?, Never> {
        
        let transform: (GoogleCalendar.EventOrigin, TimeZone) -> String? = { origin, timeZone in
            guard let recurrence = origin.recurrence?.first,
                  let rrule = RRuleParser.parse(recurrence)
            else { return nil }
            
            let frequencyText = rrule.frequencyText()
            if let endOptionText = rrule.endOptionText(timeZone) {
                return "\(frequencyText)\n\(endOptionText)"
            }
            return frequencyText
        }
        
        return Publishers.CombineLatest(
            self.subject.origin.compactMap { $0 },
            self.subject.timeZone.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var conferenceModel: AnyPublisher<ConferenceModel?, Never> {
        let transform: (GoogleCalendar.EventOrigin.ConferenceData?) -> ConferenceModel?
        transform = { conference in
            return conference.flatMap { .init($0) }
        }
        
        return self.subject.origin
            .compactMap { $0 }
            .map { $0.conferenceData }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var attendees: AnyPublisher<AttendeeListViewModel?, Never> {
        let sortAndPrefix: ([GoogleCalendar.EventOrigin.Attendee]?) -> (([GoogleCalendar.EventOrigin.Attendee], Int)?) = { attendees in
            guard let attendees else { return nil }
            
            let sorted = attendees
                .filter { $0.resource != true }
                .sortAttendees()
            return (Array(sorted.prefix(10)), sorted.count)
        }
        
        let transform: (([GoogleCalendar.EventOrigin.Attendee], Int)?) -> AttendeeListViewModel?
        transform = { pair in
            guard let pair else { return nil }
            return .init(
                attendees: pair.0.map { .init($0) },
                totalCounts: pair.1
            )
        }
        return self.subject.origin
            .compactMap { $0?.attendees }
            .map(sortAndPrefix)
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var calendarModel: AnyPublisher<GoogleCalendarModel?, Never> {
        let transform: (GoogleCalendar.Tag) -> GoogleCalendarModel = { tag in
            return .init(calenarId: tag.id, name: tag.name)
        }
        return self.subject.calendarTag
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var location: AnyPublisher<String?, Never> {
        return self.subject.fields
            .compactMap { $0 }
            .map { $0.current.location }
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

    var hasChanges: AnyPublisher<Bool, Never> {
        return self.subject.fields
            .map { $0?.isChanged ?? false }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var descriptionHTMLText: AnyPublisher<String?, Never> {
        return self.subject.origin
            .compactMap { $0 }
            .map { $0.description }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var attachments: AnyPublisher<[AttachmentModel]?, Never> {
        let transform: ([GoogleCalendar.EventOrigin.Attachment]?) -> [AttachmentModel]? = { attachments in
            
            return attachments?.compactMap { attachment in
                guard let id = attachment.fileId,
                      let fileURL = attachment.fileUrl,
                      let title = attachment.title
                else { return nil }
                return .init(
                    id: id, fileURL: fileURL, title: title, iconLink: attachment.iconLink
                )
            }
        }
        return self.subject.origin
            .compactMap { $0 }
            .map { $0.attachments }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}


// MARK: - GoogleCalendarEventDetailViewModelImple + GoogleCalendarEventEditSceneListener

extension GoogleCalendarEventDetailViewModelImple: GoogleCalendarEventEditSceneListener {

    func googleCalendarEvent(didUpdate event: GoogleCalendar.EventOrigin) {
        guard !event.isRecurringSeriesMaster else {
            self.refresh()
            return
        }
        self.applyLoaded(event)
    }

    func googleCalendarEvent(didRemove eventId: String) {
        self.router?.closeScene()
    }
}


private extension Array where Element == GoogleCalendar.EventOrigin.Attendee {
    
    func sortAttendees() -> Array {
        
        let organizer = self.first(where: { $0.organizer == true })
        let selfValue = self.first(where: { $0.selfValue == true })
        let notOrganizerOrSelfValue: (Element) -> Bool = {
            return $0.identifier != organizer?.identifier
                && $0.identifier != selfValue?.identifier
        }
        let attendees = self.filter(notOrganizerOrSelfValue)
        let accepts = attendees.filter { $0.isAccepted }
        let notAccepts = attendees.filter { !$0.isAccepted }
        
        let prefix = organizer?.identifier != selfValue?.identifier ? [organizer, selfValue] : [organizer]
        return prefix.compactMap { $0 } + accepts + notAccepts
    }
}

private extension GoogleCalendar.EventOrigin.Attendee {

    var identifier: String? {
        return self.id ?? self.email
    }

    var displayNameOrEmail: String? {
        return self.displayName ?? self.email
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

    var startDate: Date {
        switch self {
        case .at(let time): return time.date
        case .singleAllDay(let time): return time.date
        case .period(let start, _): return start.date
        case .alldayPeriod(let start, _): return start.date
        }
    }
}
