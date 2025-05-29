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
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - GoogleCalendarEventDetailViewModel

struct AttendeeViewModelModel {
    
    var thumbnailPath: String?
    let name: String
    var isOrganizer: Bool = false
    var isAccepted: Bool = false
}

struct GoogleCalendarModel: Equatable {
    let calenarId: String
    let name: String
    var colorId: String?
    var colorHex: String?
}

struct AttachmentModel: Equatable {
    let fileURL: String
    let title: String
    var iconLink: String?
}

protocol GoogleCalendarEventDetailViewModel: AnyObject, Sendable, GoogleCalendarEventDetailSceneInteractor {

    // interactor
    func refresh()
    func editEvent()
    func selectLink(_ link: URL)
    func close()
    
    // presenter
    var hasDetailLink: AnyPublisher<Bool, Never> { get }
    var eventName: AnyPublisher<String, Never> { get }
    var timeText: AnyPublisher<SelectedTime?, Never> { get }
    var repeatOPtion: AnyPublisher<String?, Never> { get }
    var calendarModel: AnyPublisher<GoogleCalendarModel?, Never> { get }
    var location: AnyPublisher<String?, Never> { get }
//    var attendeeModels: AnyPublisher<[AttendeeViewModelModel], Never> { get }
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
    var router: (any GoogleCalendarEventDetailRouting)?
    
    init(
        calenadrId: String,
        eventId: String,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.calendarId = calenadrId
        self.eventId = eventId
        self.googleCalendarUsecase = googleCalendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        
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
                self?.subject.origin.send(event)
            }, receiveError: { [weak self] error in
                self?.router?.showError(error)
            })
            .store(in: &self.cancellables)
    }
    
    func editEvent() {
        
        guard let link = self.subject.origin.value?.htmlLink
        else { return }
        
        self.router?.routeToEditEventWebView(link)
    }
    
    func selectLink(_ link: URL) {
        self.router?.openSafari(link.absoluteString)
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
    
    var calendarModel: AnyPublisher<GoogleCalendarModel?, Never> {
        let transform: (GoogleCalendar.Tag) -> GoogleCalendarModel = { tag in
            return .init(calenarId: tag.id, name: tag.name)
                |> \.colorId .~ tag.colorId
                |> \.colorHex .~ tag.backgroundColorHex
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
                guard let fileURL = attachment.fileUrl,
                      let title = attachment.title
                else { return nil }
                return .init(
                    fileURL: fileURL, title: title, iconLink: attachment.iconLink
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
