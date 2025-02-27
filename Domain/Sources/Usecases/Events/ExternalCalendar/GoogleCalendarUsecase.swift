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
    
//    func refreshEvents(in period: Range<TimeInterval>)
//    func events(in period: Range<TimeInterval>) -> AnyPublisher<[GoogleCalendar.Event], Never>
//    func event(_ eventId: String) -> AnyPublisher<GoogleCalendar.Event, any Error>
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
    }
    private let subject = Subject()
    private var cancelBag: Set<AnyCancellable> = []
    private func clearCancelBag() {
        self.cancelBag.forEach { $0.cancel() }
        self.cancelBag = []
    }
}


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
                    // TODO: clear event
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
        }
        self.repository.loadCalendarTags()
            .sink(receiveValue: updateTags)
            .store(in: &self.cancelBag)
    }
    
    private func clearGoogleCalendarEventTag() {
        self.sharedDataStore.update([])
    }
}

extension GoogleCalendarUsecaseImple {
    
    public func refreshEvents(in period: Range<TimeInterval>) {
        guard self.subject.hasAccount.value else { return }
    }
    public func events(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], Never> {
        return Empty().eraseToAnyPublisher()
    }
    
    public func event(
        _ eventId: String
    ) -> AnyPublisher<GoogleCalendar.Event, any Error> {
        return Empty().eraseToAnyPublisher()
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
