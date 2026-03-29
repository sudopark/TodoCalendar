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
                    self.refreshCalendarTags(isNew: true)

                case .disconnected:
                    self.clearCache()
                }
            }
            .store(in: &cancelBag)
    }

    private func refreshIfAlreadyIntegrated() {
        let accounts = integrationUsecase.currentIntegratedAccounts(for: appleService.identifier)
        guard !accounts.isEmpty else { return }
        refreshCalendarTags(isNew: false)
    }

    private func clearCache() {
        let tags = sharedDataStore.value(
            [AppleCalendar.Tag].self,
            key: ShareDataKeys.appleCalendarTags.rawValue
        ) ?? []
        let calendarIds = tags.map(\.id) |> Set.init

        appearanceStore.clearCalendarTags()

        sharedDataStore.delete(ShareDataKeys.appleCalendarTags.rawValue)
        sharedDataStore.update(
            [String: AppleCalendar.Event].self,
            key: ShareDataKeys.appleCalendarEvents.rawValue
        ) { existing in
            (existing ?? [:]).filter { !calendarIds.contains($0.value.calendarId) }
        }

        eventTagUsecase.removeEventTagOffIds(tags.map(\.tagId))

        Task { try? await repository.resetCache() }
    }
}


// MARK: - tags

extension AppleCalendarUsecaseImple {

    public func refreshCalendarTags() {
        refreshCalendarTags(isNew: false)
    }

    private func refreshCalendarTags(isNew: Bool) {
        Task { [weak self] in
            guard let self else { return }
            guard let tags = try? await self.repository.loadCalendarTags() else { return }
            if isNew {
                self.setInitialOffTagIds(from: tags)
            }
            self.sharedDataStore.put(
                [AppleCalendar.Tag].self,
                key: ShareDataKeys.appleCalendarTags.rawValue,
                tags
            )
            self.appearanceStore.applyCalendarTags(tags)
        }
        .store(in: &cancelBag)
    }

    private func setInitialOffTagIds(from tags: [AppleCalendar.Tag]) {
        // Apple Calendar은 연동 시 기본 숨김 (외부 캘린더 공통 정책)
        let offIds = tags.map(\.tagId)
        guard !offIds.isEmpty else { return }
        eventTagUsecase.addEventTagOffIds(offIds)
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

        Task { [weak self] in
            guard let self else { return }
            let timeZone = self.sharedDataStore.value(
                TimeZone.self,
                key: ShareDataKeys.timeZone.rawValue
            ) ?? .current
            guard let events = try? await self.repository.loadEvents(
                in: period, timeZone: timeZone
            ) else { return }
            self.sharedDataStore.put(
                [String: AppleCalendar.Event].self,
                key: ShareDataKeys.appleCalendarEvents.rawValue,
                events.asDictionary { $0.eventId }
            )
        }
        .store(in: &refreshEventBag)
    }

    public func events(in period: Range<TimeInterval>) -> AnyPublisher<[AppleCalendar.Event], Never> {
        sharedDataStore.observe(
            [String: AppleCalendar.Event].self,
            key: ShareDataKeys.appleCalendarEvents.rawValue
        )
        .map { dict in
            (dict?.values.map { $0 } ?? []).filter { $0.eventTime.isRoughlyOverlap(with: period) }
        }
        .eraseToAnyPublisher()
    }
}


// MARK: - Task store helper

private extension Task where Success == Void, Failure == Never {
    func store(in bag: inout Set<AnyCancellable>) {
        let cancellable = AnyCancellable { self.cancel() }
        bag.insert(cancellable)
    }
}
