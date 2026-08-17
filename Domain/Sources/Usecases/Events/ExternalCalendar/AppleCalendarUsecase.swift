//
//  AppleCalendarUsecase.swift
//  Domain
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - AppleCalendarViewAppearanceStore

public protocol AppleCalendarViewAppearanceStore: Sendable {
    func applyCalendarTags(_ tags: [AppleCalendar.Tag])
    func clearCalendarTags()
}


// MARK: - AppleCalendarUsecase

public protocol AppleCalendarUsecase: Sendable {

    func prepare()
    func refreshCalendarTags()
    func refreshEvents(in period: Range<TimeInterval>)

    var calendarTags: AnyPublisher<[AppleCalendar.Tag], Never> { get }
    func events(in period: Range<TimeInterval>) -> AnyPublisher<[AppleCalendar.Event], Never>
    func eventOrigin(id: String) -> AnyPublisher<AppleCalendar.EventOrigin?, Never>

    /// nil = 아직 판정 불가 (소비측이 판단을 미룬다)
    func isCalendarWritable(_ calendarId: String) -> AnyPublisher<Bool?, Never>

    func updateEvent(
        _ eventId: String,
        params: AppleCalendar.EventEditParams,
        scope: AppleCalendar.EventEditScope
    ) async throws -> AppleCalendar.EventOrigin

    func removeEvent(
        _ eventId: String,
        scope: AppleCalendar.EventEditScope
    ) async throws
}


// MARK: - AppleCalendarUsecaseImple

public final class AppleCalendarUsecaseImple: AppleCalendarUsecase, @unchecked Sendable {

    private let appleService: AppleCalendarService
    private let integrationUsecase: any ExternalCalendarIntegrationUsecase
    private let repository: any AppleCalendarRepository
    private let eventTagUsecase: any EventTagUsecase
    private let appearanceStore: any AppleCalendarViewAppearanceStore
    private let sharedDataStore: SharedDataStore

    public init(
        appleService: AppleCalendarService,
        integrationUsecase: any ExternalCalendarIntegrationUsecase,
        repository: any AppleCalendarRepository,
        eventTagUsecase: any EventTagUsecase,
        appearanceStore: any AppleCalendarViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.appleService = appleService
        self.integrationUsecase = integrationUsecase
        self.repository = repository
        self.eventTagUsecase = eventTagUsecase
        self.appearanceStore = appearanceStore
        self.sharedDataStore = sharedDataStore
    }

    private var cancelBag: Set<AnyCancellable> = []
    private var refreshEventBag: Set<AnyCancellable> = []

    private func clearCancelBag() {
        cancelBag.forEach { $0.cancel() }
        cancelBag = []
    }
}


// MARK: - prepare & integration status

extension AppleCalendarUsecaseImple {

    public func prepare() {
        clearCancelBag()

        refreshIfAlreadyIntegrated()

        integrationUsecase.integrationStatusChanged(for: appleService.identifier)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .integrated:
                    self.loadAndApplyCalendarTags()

                case .disconnected:
                    self.clearCache()
                }
            }
            .store(in: &cancelBag)
    }

    private func refreshIfAlreadyIntegrated() {
        let accounts = integrationUsecase.currentIntegratedAccounts(for: appleService.identifier)
        guard !accounts.isEmpty else { return }
        loadAndApplyCalendarTags()
    }

    private func clearCache() {
        appearanceStore.clearCalendarTags()
        sharedDataStore.delete(ShareDataKeys.appleCalendarTags.rawValue)
        sharedDataStore.delete(ShareDataKeys.appleCalendarEvents.rawValue)
        eventTagUsecase.resetExternalCalendarOffTagId(appleService.identifier)
        Task { try? await repository.resetCache() }
    }
}


// MARK: - tags

extension AppleCalendarUsecaseImple {

    public func refreshCalendarTags() {
        let accounts = integrationUsecase.currentIntegratedAccounts(for: appleService.identifier)
        guard !accounts.isEmpty else { return }
        loadAndApplyCalendarTags()
    }

    private func loadAndApplyCalendarTags() {
        repository.loadCalendarTags()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] tags in
                    guard let self else { return }
                    self.sharedDataStore.put(
                        [AppleCalendar.Tag].self,
                        key: ShareDataKeys.appleCalendarTags.rawValue,
                        tags
                    )
                    self.appearanceStore.applyCalendarTags(tags)
                }
            )
            .store(in: &cancelBag)
    }

    public var calendarTags: AnyPublisher<[AppleCalendar.Tag], Never> {
        sharedDataStore.observe(
            [AppleCalendar.Tag].self,
            key: ShareDataKeys.appleCalendarTags.rawValue
        )
        .map { $0 ?? [] }
        .eraseToAnyPublisher()
    }
}


// MARK: - events

extension AppleCalendarUsecaseImple {

    public func refreshEvents(in period: Range<TimeInterval>) {
        refreshEventBag.forEach { $0.cancel() }
        refreshEventBag = []

        integrationUsecase.currentOrNewIntegratedAccount(for: appleService.identifier)
            .flatMap { [weak self] _ -> AnyPublisher<[AppleCalendar.Event], Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.repository.loadEvents(in: period)
                    .replaceError(with: [])
                    .eraseToAnyPublisher()
            }
            .sink { [weak self] events in self?.updateStoredEvents(events, in: period) }
            .store(in: &refreshEventBag)
    }

    private func updateStoredEvents(_ refreshed: [AppleCalendar.Event], in period: Range<TimeInterval>) {
        sharedDataStore.update(
            [String: AppleCalendar.Event].self,
            key: ShareDataKeys.appleCalendarEvents.rawValue
        ) { old in
            let cachedInRange = (old ?? [:]).filter { $0.value.eventTime.isRoughlyOverlap(with: period) }
            let newMap = refreshed.asDictionary { $0.eventId }
            let removed = cachedInRange.filter { newMap[$0.key] == nil }
            let eventsWithoutRemoved = (old ?? [:]).filter { removed[$0.key] == nil }
            return refreshed.reduce(into: eventsWithoutRemoved) { $0[$1.eventId] = $1 }
        }
    }

    public func events(in period: Range<TimeInterval>) -> AnyPublisher<[AppleCalendar.Event], Never> {
        let shareKey = ShareDataKeys.appleCalendarEvents.rawValue
        return sharedDataStore.observe([String: AppleCalendar.Event].self, key: shareKey)
            .map { dict in (dict ?? [:]).values.filter { $0.eventTime.isRoughlyOverlap(with: period) } }
            .eraseToAnyPublisher()
    }

    public func eventOrigin(id: String) -> AnyPublisher<AppleCalendar.EventOrigin?, Never> {
        return self.repository.loadEventOrigin(id: id)
    }
}


// MARK: - write commands

extension AppleCalendarUsecaseImple {

    public func isCalendarWritable(_ calendarId: String) -> AnyPublisher<Bool?, Never> {
        return self.calendarTags
            .map { $0.first(where: { $0.id == calendarId })?.isWritable }
            .eraseToAnyPublisher()
    }

    public func updateEvent(
        _ eventId: String,
        params: AppleCalendar.EventEditParams,
        scope: AppleCalendar.EventEditScope
    ) async throws -> AppleCalendar.EventOrigin {
        let origin = try await self.repository.updateEvent(eventId, params, scope: scope)
        // 판단 기준은 결과가 아니라 대상이다 — "이번만" 수정은 그 회차를 시리즈에서 떼어내
        // 결과가 비반복이 되는데, 정작 재조회가 필요한 건 회차가 빠진 원본 시리즈 쪽이다
        if self.isRepeatingOccurrence(eventId) {
            if let period = self.cachedEventsPeriod() {
                self.refreshEvents(in: period)
            }
        } else {
            self.cacheUpdatedEvent(origin)
        }
        return origin
    }

    private func isRepeatingOccurrence(_ eventId: String) -> Bool {
        return AppleCalendar.EventOccurrenceId(eventId).occurrenceDate != nil
    }

    private func cachedEventsPeriod() -> Range<TimeInterval>? {
        let cached = self.sharedDataStore.value(
            [String: AppleCalendar.Event].self, key: ShareDataKeys.appleCalendarEvents.rawValue
        ) ?? [:]
        guard let lower = cached.values.map({ $0.eventTime.lowerBoundWithFixed }).min(),
              let upper = cached.values.map({ $0.eventTime.upperBoundWithFixed }).max(),
              lower < upper
        else { return nil }
        return lower..<upper
    }

    private func cacheUpdatedEvent(_ origin: AppleCalendar.EventOrigin) {
        let event = origin.asEvent()
        self.sharedDataStore.update(
            [String: AppleCalendar.Event].self,
            key: ShareDataKeys.appleCalendarEvents.rawValue
        ) { existing in
            (existing ?? [:]) |> key(event.eventId) .~ event
        }
    }

    public func removeEvent(
        _ eventId: String,
        scope: AppleCalendar.EventEditScope
    ) async throws {
        try await self.repository.removeEvent(eventId, scope: scope)
        self.sharedDataStore.update(
            [String: AppleCalendar.Event].self,
            key: ShareDataKeys.appleCalendarEvents.rawValue
        ) { existing in
            (existing ?? [:]) |> key(eventId) .~ nil
        }
        if scope == .thisAndFuture, let period = self.cachedEventsPeriod() {
            self.refreshEvents(in: period)
        }
    }
}
