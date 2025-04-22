//
//  GoogleCalendarUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - GoogleCalendarViewAppearanceStore

public protocol GoogleCalendarViewAppearanceStore: Sendable {
    
    func apply(colors: GoogleCalendar.Colors)
    func clearGoogleCalendarColors()
}


// MARK: - GoogleCalendarUsecase

public protocol GoogleCalendarUsecase: Sendable {
    
    func prepare()
    
    func refreshEvents(in period: Range<TimeInterval>)
    
    func events(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], Never>
    
    func eventDetail(
        _ calendarId: String,
        _ eventId: String,
        at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error>
}


public final class GoogleCalendarUsecaseImple: GoogleCalendarUsecase, @unchecked Sendable {
    
    private let googleService: GoogleCalendarService
    private let repository: any GoogleCalendarRepository
    private let appearanceStore: any GoogleCalendarViewAppearanceStore
    private let sharedDataStore: SharedDataStore
    
    public init(
        googleService: GoogleCalendarService,
        repository: any GoogleCalendarRepository,
        appearanceStore: any GoogleCalendarViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.googleService = googleService
        self.repository = repository
        self.appearanceStore = appearanceStore
        self.sharedDataStore = sharedDataStore
    }
    
    private struct Subject {
        let hasAccount = CurrentValueSubject<Bool, Never>(false)
        let calendars = CurrentValueSubject<[GoogleCalendar.Tag], Never>([])
    }
    private let subject = Subject()
    private var cancelBag: Set<AnyCancellable> = []
    private var refreshEventBag: Set<AnyCancellable> = []
    private func clearCancelBag() {
        self.cancelBag.forEach { $0.cancel() }
        self.cancelBag = []
    }
}


// MARK: - color and tags

extension GoogleCalendarUsecaseImple {
    
    public func prepare() {
        
        self.clearCancelBag()
        
        let serviceId = self.googleService.identifier
        let hasAccount = self.sharedDataStore
            .observe(
                [String: ExternalServiceAccountinfo].self,
                key: ShareDataKeys.externalCalendarAccounts.rawValue
            )
            .map { $0?[serviceId] != nil }
        
        hasAccount
            .removeDuplicates()
            .sink(receiveValue: { [weak self] has in
                self?.subject.hasAccount.send(has)
                if has {
                    self?.refreshColors()
                    self?.refreshGoogleCalendarEventTags()
                } else {
                    self?.appearanceStore.clearGoogleCalendarColors()
                    self?.clearGoogleCalendarEventTag()
                    self?.subject.calendars.send([])
                    self?.sharedDataStore.delete(
                        ShareDataKeys.googleCalendarEvents.rawValue
                    )
                }
            })
            .store(in: &self.cancelBag)
    }
    
    private func refreshColors() {
        self.repository.loadColors()
            .sink(receiveValue: { [weak self] colors in
                self?.appearanceStore.apply(colors: colors)
            })
            .store(in: &self.cancelBag)
    }
    
    private func refreshGoogleCalendarEventTags() {
        let updateTags: ([GoogleCalendar.Tag]) -> Void = { [weak self] tags in
            self?.sharedDataStore.update(tags)
            self?.subject.calendars.send(tags)
        }
        self.repository.loadCalendarTags()
            .sink(receiveValue: updateTags)
            .store(in: &self.cancelBag)
    }
    
    private func clearGoogleCalendarEventTag() {
        self.sharedDataStore.update([])
    }
}


// MARK: - events

extension GoogleCalendarUsecaseImple {
    
    private func cancelRefresh() {
        self.refreshEventBag.forEach { $0.cancel() }
        self.refreshEventBag = []
    }
    
    public func refreshEvents(in period: Range<TimeInterval>) {
        guard self.subject.hasAccount.value else { return }
        
        self.cancelRefresh()
        
        self.subject.calendars
            .sink(receiveValue: { [weak self] calednars in
                guard let self = self else { return }
                calednars.forEach {
                    self.refreshEvents($0.id, in: period)
                }
            })
            .store(in: &self.refreshEventBag)
    }
    
    private func refreshEvents(
        _ calendarId: String, in period: Range<TimeInterval>
    ) {
       
        let updateEvents: ([GoogleCalendar.Event]) -> Void = { [weak self] events in
            
            let newMap = events.asDictionary { $0.eventId }
            self?.sharedDataStore.update(
                [String: GoogleCalendar.Event].self,
                key: ShareDataKeys.googleCalendarEvents.rawValue
            ) { old in
                return (old ?? [:]).merging(newMap) { $1 }
            }
        }
        
        self.repository.loadEvents(calendarId, in: period)
            .sink(receiveValue: updateEvents)
            .store(in: &self.refreshEventBag)
    }
    
    public func events(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], Never> {
        let shareKey = ShareDataKeys.googleCalendarEvents.rawValue
        
        let filterInRange: ([GoogleCalendar.Event]) -> [GoogleCalendar.Event] = { events in
            return events.filter { event in
                return event.eventTime.isRoughlyOverlap(with: period)
            }
        }
        return self.sharedDataStore
            .observe([String: GoogleCalendar.Event].self, key: shareKey)
            .map { $0?.values.map { $0 } ?? [] }
            .map(filterInRange)
            .eraseToAnyPublisher()
    }
    
    public func eventDetail(
        _ calendarId: String,
        _ eventId: String,
        at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        
        return self.repository.loadEventDetail(
            calendarId, timeZone.identifier, eventId
        )
    }
}

private extension SharedDataStore {
    
    func update(_ tags: [GoogleCalendar.Tag]) {
        let newDict = tags.reduce(into: [EventTagId: GoogleCalendar.Tag]()) { acc, tag in
            acc[tag.tagId] = tag
        }
        self.update(
            [EventTagId: any EventTag].self, key: ShareDataKeys.tags.rawValue
        ) { allDict in
            return (allDict ?? [:])
                .filter { $0.key.externalServiceId != GoogleCalendarService.id }
                .merging(newDict) { $1 }
        }
    }
}
