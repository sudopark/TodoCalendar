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
        self.id = attendee.id
        self.name = attendee.displayName ?? "eventDetail::gogoleEvent::attendee::unknown".localized()
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
    func selectLink(_ link: URL)
    func selectAttachment(_ model: AttachmentModel)
    func copyText(_ text: String)
    func close()
    
    // presenter
    var hasDetailLink: AnyPublisher<Bool, Never> { get }
    var eventColorModel: AnyPublisher<GoogleCalendarEventColorModel, Never> { get }
    var eventName: AnyPublisher<String, Never> { get }
    var timeText: AnyPublisher<SelectedTime?, Never> { get }
    var ddayText: AnyPublisher<String, Never> { get }
    var repeatOPtion: AnyPublisher<String?, Never> { get }
    var calendarModel: AnyPublisher<GoogleCalendarModel?, Never> { get }
    var location: AnyPublisher<String?, Never> { get }
    var conferenceModel: AnyPublisher<ConferenceModel?, Never> { get }
    var attendees: AnyPublisher<AttendeeListViewModel?, Never> { get }
    // 회의 모델
    var descriptionHTMLText: AnyPublisher<String?, Never> { get }
    var attachments: AnyPublisher<[AttachmentModel]?, Never> { get }
}


// MARK: - GoogleCalendarEventDetailViewModelImple

final class GoogleCalendarEventDetailViewModelImple: GoogleCalendarEventDetailViewModel, @unchecked Sendable {
    
    private let calendarId: String
    private let eventId: String
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let daysIntervalCountUsecase: any DaysIntervalCountUsecase
    var router: (any GoogleCalendarEventDetailRouting)?
    
    init(
        calenadrId: String,
        eventId: String,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        daysIntervalCountUsecase: any DaysIntervalCountUsecase
    ) {
        self.calendarId = calenadrId
        self.eventId = eventId
        self.googleCalendarUsecase = googleCalendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.daysIntervalCountUsecase = daysIntervalCountUsecase
        
        self.internalBind()
    }
    
    
    private struct Subject {
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let origin = CurrentValueSubject<GoogleCalendar.EventOrigin?, Never>(nil)
        let calendarTag = CurrentValueSubject<GoogleCalendar.Tag?, Never>(nil)
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
    }
}


// MARK: - GoogleCalendarEventDetailViewModelImple Interactor

extension GoogleCalendarEventDetailViewModelImple {
    
    func refresh() {
        
        let currentTimeZone = self.subject.timeZone.compactMap { $0 }.first()
        let eventOrigin = currentTimeZone.flatMap { [weak self] timeZone -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.googleCalendarUsecase.eventDetail(self.calendarId, self.eventId, at: timeZone).eraseToAnyPublisher()
        }
        eventOrigin
            .sink(receiveValue: { [weak self] event in
                if event.status == .cancelled {
                    self?.alertEventCanceled()
                    return
                }
                self?.subject.origin.send(event)
            }, receiveError: { [weak self] error in
                self?.router?.showError(error)
            })
            .store(in: &self.cancellables)
    }
    
    private func alertEventCanceled() {
        self.router?.showToast("eventDetail::gogoleEvent::canceled::message".localized())
        self.router?.closeScene()
    }
    
    func editEvent() {
        
        guard let link = self.subject.origin.value?.htmlLink
        else { return }
        
        self.router?.routeToEditEventWebView(link)
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


// MARK: - GoogleCalendarEventDetailViewModelImple Presenter

extension GoogleCalendarEventDetailViewModelImple {
    
    var hasDetailLink: AnyPublisher<Bool, Never> {
        return self.subject.origin
            .compactMap { $0 }
            .map { $0.htmlLink != nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var eventColorModel: AnyPublisher<GoogleCalendarEventColorModel, Never> {
        let calendarId = self.calendarId
        return self.subject.origin
            .compactMap { $0 }
            .map {
                GoogleCalendarEventColorModel(colorId: $0.colorId, calendarId: calendarId)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var eventName: AnyPublisher<String, Never> {
        
        return self.subject.origin
            .compactMap { $0 }
            .map { $0.summary }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var timeText: AnyPublisher<SelectedTime?, Never> {
        let transform: (GoogleCalendar.EventOrigin, TimeZone) -> SelectedTime? = { origin, timeZone in
            
            let start = origin.start?.supportEventTimeElemnt(timeZone.identifier)
            let end = origin.end?.supportEventTimeElemnt(timeZone.identifier)
            
            switch (start, end) {
            case (.period(let st), .period(let et)):
                let time = EventTime.period(
                    st.timeIntervalSince1970..<et.timeIntervalSince1970
                )
                return .init(time, timeZone)
                
            case(.allDay(let st, let sz), .allDay(let et, _)):
                let time = EventTime.allDay(
                    st.timeIntervalSince1970..<et.timeIntervalSince1970,
                    secondsFromGMT: TimeInterval(sz.secondsFromGMT())
                )
                return .init(time, timeZone)
                
            default: return nil
            }
        }
        
        return Publishers.CombineLatest(
            self.subject.origin.compactMap { $0 },
            self.subject.timeZone.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var ddayText: AnyPublisher<String, Never> {
        typealias SupportTime = GoogleCalendar.EventOrigin.GoogleEventTime.SupportEventTimeElemnt
        let asEventTime: (GoogleCalendar.EventOrigin, TimeZone) -> SupportTime?
        asEventTime = { origin, timeZone in
            return origin.start?.supportEventTimeElemnt(timeZone.identifier)
        }
        
        let countDays: (SupportTime?) -> AnyPublisher<Int, Never> = { [weak self] time in
            guard let self = self, let time else { return Empty().eraseToAnyPublisher() }
            let start  = switch time {
                case .period(let date): date
                case .allDay(let date, _): date
            }
            return self.daysIntervalCountUsecase.countDays(to: start)
        }
        
        return Publishers.CombineLatest(
            self.subject.origin.compactMap { $0 },
            self.subject.timeZone.compactMap { $0 }
        )
        .map(asEventTime)
        .map(countDays)
        .switchToLatest()
        .removeDuplicates()
        .map { DDayText($0).text }
        .eraseToAnyPublisher()
    }
    
    var repeatOPtion: AnyPublisher<String?, Never> {
        
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
            
            let sorted = attendees.sortAttendees()
            return (Array(sorted.prefix(10)), attendees.count)
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
        return self.subject.origin
            .compactMap { $0 }
            .map { $0.location }
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

private extension RRule {
    
    func frequencyText() -> String {
        switch self.freq {
        case .DAILY where self.interval == 1:
            return "eventDetail.repeating.everyDay:title".localized()
            
        case .DAILY:
            return  "eventDetail.repeating.everyNDays:title".localized(with: self.interval)
            
        case .WEEKLY where self.interval == 1:
            return "eventDetail.repeating.everyWeek:title".localized()
                .appendDaysText(self.byDays)
            
        case .WEEKLY:
            return "eventDetail.repeating.everySomeWeek:title".localized(with: self.interval)
                .appendDaysText(self.byDays)
            
        case .MONTHLY where self.interval == 1:
            return "eventDetail.repeating.everyMonth:title".localized()
                .appendDaysText(self.byDays)
            
        case .MONTHLY:
            return "eventDetail.repeating.everyNMonths:title".localized(with: self.interval)
                .appendDaysText(self.byDays)
            
        case .YEARLY where self.interval == 1:
            return "eventDetail.repeating.everyYear:title".localized()
            
        case .YEARLY:
            return "eventDetail.repeating.everyNYears:title".localized(with: self.interval)
        }
    }
    
    func endOptionText(_ timeZone: TimeZone) -> String? {
        if let until = self.until {
            let dateText = until.text("date_form.yyyy_MMM_dd".localized(), timeZone: timeZone)
            return "eventDetail.repeating::endoption_until".localized(with: dateText)
        } else  if let count = self.count {
            return "eventDetail.repeating::endoption_times".localized(with: count)
        } else {
            return nil
        }
    }
}

private extension String {
    
    func appendDaysText(_ byDays: [RRule.ByDay]) -> String {
        guard !byDays.isEmpty else { return self }
        let texts = byDays.map { $0.text() }.joined(separator: ",")
        return "\(self) \(texts)"
    }
}

private extension RRule.ByDay {
    
    func text() -> String {
        switch self.ordinal {
        case .none:
            return self.weekDay.text()
        case .some(let n) where n == -1:
            return "\("eventDetail.repeating.last".localized()) \(self.weekDay.text())"
        case .some(let n):
            return n.ordinal.map { "\($0) \(self.weekDay.text())"} ?? self.weekDay.text()
        }
    }
}

private extension RRule.ByDay.WeekDay {
    
    func text() -> String {
        switch self {
        case .MO: return "dayname::monday:short".localized()
        case .TU: return "dayname::tuesday:short".localized()
        case .WE: return "dayname::wednesday:short".localized()
        case .TH: return "dayname::thursday:short".localized()
        case .FR: return "dayname::friday:short".localized()
        case .SA: return "dayname::saturday:short".localized()
        case .SU: return "dayname::sunday:short".localized()
        }
    }
}

private extension Array where Element == GoogleCalendar.EventOrigin.Attendee {
    
    func sortAttendees() -> Array {
        
        let organizer = self.first(where: { $0.organizer == true })
        let selfValue = self.first(where: { $0.selfValue == true })
        let notOrganizerOrSelfValue: (Element) -> Bool = {
            return $0.id != nil && $0.id != organizer?.id && $0.id != selfValue?.id
        }
        let attendees = self.filter(notOrganizerOrSelfValue)
        let accepts = attendees.filter { $0.isAccepted }
        let notAccepts = attendees.filter { !$0.isAccepted }
        
        let prefix = organizer?.id != selfValue?.id ? [organizer, selfValue] : [organizer]
        return prefix.compactMap { $0 } + accepts + notAccepts
    }
    
    private func sortByOrganizer(_ lhs: Element, _ rhs: Element) -> Bool? {
        switch (lhs.organizer == true, rhs.organizer == true) {
        case (false, true): return false
        case (true, false): return true
        default: return nil
        }
    }
    
    private func sortBySelf(_ lhs: Element, _ rhs: Element) -> Bool? {
        switch (lhs.selfValue == true, rhs.selfValue == true) {
        case (false, true): return false
        case (true, false): return true
        default: return nil
        }
    }
    
    private func sortByAccpet(_ lhs: Element, _ rhs: Element) -> Bool {
        switch (lhs.isAccepted, rhs.isAccepted) {
        case (false, true): return false
        case (true, false): return true
        default: return (lhs.displayName ?? "") < (rhs.displayName ?? "")
        }
    }
}
