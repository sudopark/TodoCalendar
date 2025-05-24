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

protocol GoogleCalendarEventDetailViewModel: AnyObject, Sendable, GoogleCalendarEventDetailSceneInteractor {

    // interactor
    func refresh()
    func editEvent()
    func close()
    
    // presenter
    var eventName: AnyPublisher<String, Never> { get }
    var timeText: AnyPublisher<SelectedTime?, Never> { get }
    var repeatOPtion: AnyPublisher<String?, Never> { get }
    var calendarModel: AnyPublisher<GoogleCalendarModel?, Never> { get }
    var location: AnyPublisher<String?, Never> { get }
//    var attendeeModels: AnyPublisher<[AttendeeViewModelModel], Never> { get }
    // 회의 모델
    // 메모 정보
    // 첨부파일 정보
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
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - GoogleCalendarEventDetailViewModelImple Presenter

extension GoogleCalendarEventDetailViewModelImple {
    
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
        return Empty().eraseToAnyPublisher()
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
}
