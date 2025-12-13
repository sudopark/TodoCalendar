//
//  GoogleCalendarUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - GoogleCalendarViewAppearanceStore

public protocol GoogleCalendarViewAppearanceStore: Sendable {
    
    func apply(colors: GoogleCalendar.Colors)
    func apply(googleCalendarTags: [GoogleCalendar.Tag])
    func clearGoogleCalendarColors()
}


// MARK: - GoogleCalendarUsecase

public protocol GoogleCalendarUsecase: Sendable {
    
    func prepare()
    
    // calendar
    func refreshGoogleCalendarEventTags()
    
    var calendarTags: AnyPublisher<[GoogleCalendar.Tag], Never> { get }
    
    // events
    func refreshEvents(in period: Range<TimeInterval>)
    
    func events(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], Never>
    
    func eventDetail(
        _ calendarId: String,
        _ eventId: String,
        at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error>
    
    var integratedAccount: AnyPublisher<ExternalServiceAccountinfo?, Never> { get }
}


public final class GoogleCalendarUsecaseImple: GoogleCalendarUsecase, @unchecked Sendable {
    
    private let googleService: GoogleCalendarService
    private let repository: any GoogleCalendarRepository
    private let eventTagUsecase: any EventTagUsecase
    private let appearanceStore: any GoogleCalendarViewAppearanceStore
    private let sharedDataStore: SharedDataStore
    
    public init(
        googleService: GoogleCalendarService,
        repository: any GoogleCalendarRepository,
        eventTagUsecase: any EventTagUsecase,
        appearanceStore: any GoogleCalendarViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.googleService = googleService
        self.repository = repository
        self.eventTagUsecase = eventTagUsecase
        self.appearanceStore = appearanceStore
        self.sharedDataStore = sharedDataStore
    }
    
    private var cancelBag: Set<AnyCancellable> = []
    private var refreshEventBag: Set<AnyCancellable> = []
    private func clearCancelBag() {
        self.cancelBag.forEach { $0.cancel() }
        self.cancelBag = []
    }
}


// MARK: - color and tags

extension GoogleCalendarUsecaseImple {
    
    private struct AccountAndIsNew: Equatable {
        let account: ExternalServiceAccountinfo
        private var lastIntegrationTime: Date?
        var isNew: Bool = false
        
        init(_ account: ExternalServiceAccountinfo) {
            self.account = account
            self.lastIntegrationTime = account.intergrationTime
            self.isNew = account.intergrationTime != nil
        }
        
        func update(_ new: ExternalServiceAccountinfo) -> AccountAndIsNew {
            guard account.serviceIdentifier == new.serviceIdentifier,
                  account.email == new.email
            else {
                return .init(new)
            }
            let isNewIntegrated = switch (account.intergrationTime, new.intergrationTime) {
            case (.some(let oldtime), .some(let newTime)) where newTime > oldtime: true
            case (.none, .some): true
            default: false
            }
            return .init(new) |> \.isNew .~ isNewIntegrated
        }
    }
    
    public func prepare() {
        
        self.clearCancelBag()
        let serviceId = self.googleService.identifier
        
        let asAccountWithCheckIsNew: (AccountAndIsNew?, ExternalServiceAccountinfo?) -> AccountAndIsNew? = { acc, account in
            guard let account else { return nil }
            return acc?.update(account) ?? AccountAndIsNew(account)
        }
        
        let account = self.sharedDataStore
            .observe(
                [String: ExternalServiceAccountinfo].self,
                key: ShareDataKeys.externalCalendarAccounts.rawValue
            )
            .map { $0?[serviceId] }
            .scan(nil, asAccountWithCheckIsNew)
        
        account
            .removeDuplicates()
            .sink(receiveValue: { [weak self] accountAndIsNew in
                if let accountAndIsNew {
                    self?.refreshEventTags(isFirstLoadAfterIntegrated: accountAndIsNew.isNew)
                } else {
                    self?.clearGoogleCalendarEventTag()
                    self?.sharedDataStore.delete(
                        ShareDataKeys.googleCalendarEvents.rawValue
                    )
                    
                    logger.log(level: .critical, "will clear google calendar db")
                    self?.clearGoogleCalendarCache()
                }
            })
            .store(in: &self.cancelBag)
    }
    
    public func refreshGoogleCalendarEventTags() {
        self.refreshEventTags()
    }
    
    public func refreshEventTags(isFirstLoadAfterIntegrated: Bool = false) {
        guard self.checkHasAccount() else { return }
        
        let updateTags: ([GoogleCalendar.Tag]) -> Void = { [weak self] tags in
            let tags = tags.filter { !$0.isHoliday }
            
            if isFirstLoadAfterIntegrated {
                self?.setGoogleCalendarTagInitailOffTags(from: tags)
            }
            
            self?.sharedDataStore.put(
                [GoogleCalendar.Tag].self,
                key: ShareDataKeys.googleCalendarTags.rawValue,
                tags
            )
            self?.appearanceStore.apply(googleCalendarTags: tags)
        }
        self.repository.loadCalendarTags()
            .sink(receiveValue: updateTags)
            .store(in: &self.cancelBag)
        
        self.repository.loadColors()
            .sink(receiveValue: { [weak self] colors in
                self?.appearanceStore.apply(colors: colors)
            })
            .store(in: &self.cancelBag)
    }
    
    private func setGoogleCalendarTagInitailOffTags(from tags: [GoogleCalendar.Tag]) {
        let offIds = tags.filter { $0.isSelected != true }.map { $0.tagId }
        guard !offIds.isEmpty else { return }
        self.eventTagUsecase.addEventTagOffIds(offIds)
    }
    
    private func clearGoogleCalendarEventTag() {
        self.sharedDataStore.delete(ShareDataKeys.googleCalendarTags.rawValue)
        self.appearanceStore.clearGoogleCalendarColors()
        self.eventTagUsecase.resetExternalCalendarOffTagId(self.googleService.identifier)
    }
    
    private func clearGoogleCalendarCache() {
        Task {
            try await self.repository.resetCache()
        }
    }
    
    public var calendarTags: AnyPublisher<[GoogleCalendar.Tag], Never> {
        return self.sharedDataStore.observe(
            [GoogleCalendar.Tag].self, key: ShareDataKeys.googleCalendarTags.rawValue
        )
        .map { $0 ?? [] }
        .eraseToAnyPublisher()
    }
    
    private var activeCalendarTags: AnyPublisher<[GoogleCalendar.Tag], Never> {
        
        let transform: ([GoogleCalendar.Tag], Set<EventTagId>) -> [GoogleCalendar.Tag]
        transform = { totalTags, offIds in
            return totalTags.filter { !offIds.contains($0.tagId) }
        }
        return Publishers.CombineLatest(
            self.calendarTags,
            self.eventTagUsecase.offEventTagIdsOnCalendar()
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}


// MARK: - events

extension GoogleCalendarUsecaseImple {
    
    private func cancelRefresh() {
        self.refreshEventBag.forEach { $0.cancel() }
        self.refreshEventBag = []
    }
    
    private func checkHasAccount() -> Bool {
        let accounts = self.sharedDataStore.value([String: ExternalServiceAccountinfo].self, key: ShareDataKeys.externalCalendarAccounts.rawValue)
        return accounts?[self.googleService.identifier] != nil
    }
    
    public func refreshEvents(in period: Range<TimeInterval>) {
        guard self.checkHasAccount() else { return }
        
        self.cancelRefresh()
        
        self.activeCalendarTags
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
       
        let updateEvents: ([GoogleCalendar.Event]) -> Void = { [weak self] refreshed in
            
            self?.sharedDataStore.update(
                [String: GoogleCalendar.Event].self,
                key: ShareDataKeys.googleCalendarEvents.rawValue
            ) { old in
                let cachedInRange = (old ?? [:]).filter {
                    $0.value.eventTime.isRoughlyOverlap(with: period)
                }
                let newMap = refreshed.asDictionary { $0.eventId }
                let removed = cachedInRange.filter {
                    $0.value.calendarId == calendarId && newMap[$0.key] == nil
                }
                let eventWithoutRemoved = (old ?? [:]).filter { removed[$0.key] == nil }
                return refreshed.reduce(into: eventWithoutRemoved) { $0[$1.eventId] = $1 }
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


// MARK: - account

extension GoogleCalendarUsecaseImple {
    
    public var integratedAccount: AnyPublisher<ExternalServiceAccountinfo?, Never> {
        let serviceId = self.googleService.identifier
        return self.sharedDataStore.observe(
            [String: ExternalServiceAccountinfo].self,
            key: ShareDataKeys.externalCalendarAccounts.rawValue
        )
        .map { $0?[serviceId] }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}


public extension GoogleCalendar.Tag {
    
    var isHoliday: Bool {
        return id.hasSuffix("holiday@group.v.calendar.google.com")
    }
}
