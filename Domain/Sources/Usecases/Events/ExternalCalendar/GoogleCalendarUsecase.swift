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

    func applyColors(_ colors: GoogleCalendar.Colors, for accountId: String)
    func clearColors(for accountId: String)

    func applyCalendarTags(_ tags: [GoogleCalendar.Tag], for accountId: String)
    func clearCalendarTags(for accountId: String)
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
        accountId: String,
        at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error>
}


public final class GoogleCalendarUsecaseImple: GoogleCalendarUsecase, @unchecked Sendable {

    private let googleService: GoogleCalendarService
    private let integrationUsecase: any ExternalCalendarIntegrationUsecase
    private let repositoryPool: any GoogleCalendarRepositoryPool
    private let eventTagUsecase: any EventTagUsecase
    private let appearanceStore: any GoogleCalendarViewAppearanceStore
    private let sharedDataStore: SharedDataStore

    public init(
        googleService: GoogleCalendarService,
        integrationUsecase: any ExternalCalendarIntegrationUsecase,
        repositoryPool: any GoogleCalendarRepositoryPool,
        eventTagUsecase: any EventTagUsecase,
        appearanceStore: any GoogleCalendarViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.googleService = googleService
        self.integrationUsecase = integrationUsecase
        self.repositoryPool = repositoryPool
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

    public func prepare() {
        clearCancelBag()

        self.refreshCurrentAccountGoogleCalendarInfos()

        integrationUsecase.integrationStatusChanged(for: googleService.identifier)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .integrated(_, let account):
                    guard let email = account.email else { return }
                    self.refreshColors(email)
                    self.refreshCalendarTags(email, isNew: true)

                case .disconnected(_, let email):
                    self.clearAccountCache(email)
                }
            }
            .store(in: &cancelBag)
    }

    public func refreshGoogleCalendarEventTags() {
        self.refreshCurrentAccountGoogleCalendarInfos()
    }

    private func refreshCurrentAccountGoogleCalendarInfos() {
        let accounts = self.integrationUsecase.currentIntegratedAccounts(for: googleService.identifier)
        guard !accounts.isEmpty else { return }

        accounts.forEach { account in
            if let email = account.email {
                self.refreshColors(email)
                self.refreshCalendarTags(email)
            }
        }
    }

    private func refreshColors(_ accountId: String) {
        let repository = repositoryPool.repository(for: accountId)
        repository.loadColors()
            .catch { _ in Empty() }
            .sink { [weak self] colors in
                self?.appearanceStore.applyColors(colors, for: accountId)
            }
            .store(in: &cancelBag)
    }

    private func refreshCalendarTags(_ accountId: String, isNew: Bool = false) {
        let repository = repositoryPool.repository(for: accountId)
        repository.loadCalendarTags()
            .catch { _ in Empty() }
            .sink { [weak self] tags in
                guard let self else { return }
                let incoming = tags.filter { !$0.isHoliday }
                if isNew {
                    self.setGoogleCalendarTagInitailOffTags(from: incoming)
                }
                self.sharedDataStore.update(
                    [String: [GoogleCalendar.Tag]].self,
                    key: ShareDataKeys.googleCalendarTags.rawValue
                ) { existing in
                    (existing ?? [:]) |> key(accountId) .~ incoming
                }
                self.appearanceStore.applyCalendarTags(incoming, for: accountId)
            }
            .store(in: &cancelBag)
    }

    private func clearAccountCache(_ accountId: String) {
        let accountTags = sharedDataStore.value(
            [String: [GoogleCalendar.Tag]].self,
            key: ShareDataKeys.googleCalendarTags.rawValue
        )?[accountId] ?? []
        let calendarIds = accountTags.map(\.id) |> Set.init

        appearanceStore.clearColors(for: accountId)
        appearanceStore.clearCalendarTags(for: accountId)

        sharedDataStore.update(
            [String: [GoogleCalendar.Tag]].self,
            key: ShareDataKeys.googleCalendarTags.rawValue
        ) { existing in
            (existing ?? [:]) |> key(accountId) .~ nil
        }

        sharedDataStore.update(
            [String: GoogleCalendar.Event].self,
            key: ShareDataKeys.googleCalendarEvents.rawValue
        ) { existing in
            (existing ?? [:]).filter { !calendarIds.contains($0.value.calendarId) }
        }

        eventTagUsecase.removeEventTagOffIds(accountTags.map(\.tagId))

        Task {
            try? await repositoryPool.repository(for: accountId).resetCache()
            repositoryPool.removeRepository(for: accountId)
        }
    }

    private func setGoogleCalendarTagInitailOffTags(from tags: [GoogleCalendar.Tag]) {
        let offIds = tags.filter { $0.isSelected != true }.map { $0.tagId }
        guard !offIds.isEmpty else { return }
        eventTagUsecase.addEventTagOffIds(offIds)
    }

    public var calendarTags: AnyPublisher<[GoogleCalendar.Tag], Never> {
        return sharedDataStore.observe(
            [String: [GoogleCalendar.Tag]].self, key: ShareDataKeys.googleCalendarTags.rawValue
        )
        .map { $0?.values.flatMap { $0 } ?? [] }
        .eraseToAnyPublisher()
    }

    private func activeCalendars() -> (String) -> AnyPublisher<[GoogleCalendar.Tag], Never> {
        return { [weak self] accountId in
            guard let self = self else { return Empty().eraseToAnyPublisher() }

            let calendarForAccount = self.sharedDataStore
                .observe(
                    [String: [GoogleCalendar.Tag]].self,
                    key: ShareDataKeys.googleCalendarTags.rawValue
                )
                .map { $0?[accountId] ?? [] }
                .removeDuplicates()

            let filterActive: ([GoogleCalendar.Tag], Set<EventTagId>) -> [GoogleCalendar.Tag]
            filterActive = { total, offIds in
                return total.filter { !offIds.contains($0.tagId) }
            }

            return Publishers.CombineLatest(
                calendarForAccount,
                eventTagUsecase.offEventTagIdsOnCalendar()
            )
            .map(filterActive)
            .eraseToAnyPublisher()
        }
    }
}


// MARK: - events

extension GoogleCalendarUsecaseImple {

    private func cancelRefresh() {
        refreshEventBag.forEach { $0.cancel() }
        refreshEventBag = []
    }

    public func refreshEvents(in period: Range<TimeInterval>) {
        self.cancelRefresh()

        let accounts = self.integrationUsecase.currentAndNewIntegratedGoogleAccounts()
        let activeCalendarTagPerAccount = accounts
            .compactMap { $0.email }
            .flatMap(self.activeCalendars())

        activeCalendarTagPerAccount
            .sink(receiveValue: { [weak self] calendars in
                guard let self = self else { return }
                calendars.forEach { calendar in
                    self.refreshEvents(calendar.id, accountId: calendar.ownerId, in: period)
                }
            })
            .store(in: &self.refreshEventBag)
    }

    private func refreshEvents(
        _ calendarId: String, accountId: String, in period: Range<TimeInterval>
    ) {
        let repository = self.repositoryPool.repository(for: accountId)
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

        repository.loadEvents(calendarId, in: period)
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
        accountId: String,
        at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        return self.repositoryPool.repository(for: accountId)
            .loadEventDetail(calendarId, timeZone.identifier, eventId)
    }
}

public extension GoogleCalendar.Tag {

    var isHoliday: Bool {
        return id.hasSuffix("holiday@group.v.calendar.google.com")
    }
}


private extension ExternalCalendarIntegrationUsecase {

    func currentAndNewIntegratedGoogleAccounts() -> AnyPublisher<ExternalServiceAccountinfo, Never> {

        let googleServiceId = GoogleCalendarService.id
        let currents = self.integratedServiceAccounts
            .map { $0[googleServiceId] ?? [] }
            .flatMap { $0.publisher }
        let newIntegrated = self.integrationStatusChanged
            .compactMap { status in
                switch status {
                case .integrated(let serviceId, let account) where serviceId == googleServiceId:
                    return account
                default: return nil
                }
            }

        return Publishers.Merge(currents, newIntegrated)
            .removeAllDuplicates()
            .eraseToAnyPublisher()
    }
}
