//
//  AppleCalendarUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

@testable import Domain

final class AppleCalendarUsecaseImpleTests: PublisherWaitable {

    private let appleService = AppleCalendarService()
    private let stubIntegrationUsecase = PrivateStubIntegrationUsecase()
    private let stubRepository = StubAppleCalendarRepository()
    private let stubEventTagUsecase = StubEventTagUsecase()
    private let spyAppearanceStore = SpyAppleCalendarViewAppearanceStore()
    private let stubStore = SharedDataStore()

    var cancelBag: Set<AnyCancellable>! = []

    private func makeUsecase(isIntegrated: Bool = false) -> AppleCalendarUsecaseImple {
        if isIntegrated {
            let account = ExternalServiceAccountinfo(AppleCalendarService.id, email: "local")
            stubIntegrationUsecase.setAccounts([account])
        }
        return .init(
            appleService: appleService,
            integrationUsecase: stubIntegrationUsecase,
            repository: stubRepository,
            eventTagUsecase: stubEventTagUsecase,
            appearanceStore: spyAppearanceStore,
            sharedDataStore: stubStore
        )
    }

    private func sendIntegration(_ connected: Bool) {
        let serviceId = AppleCalendarService.id
        if connected {
            let account = ExternalServiceAccountinfo(serviceId, email: "local")
            stubIntegrationUsecase.setAccounts([account])
            stubIntegrationUsecase.statusSubject.send(
                .integrated(serviceId: serviceId, account: account)
            )
        } else {
            stubIntegrationUsecase.setAccounts([])
            stubIntegrationUsecase.statusSubject.send(
                .disconnected(serviceId: serviceId, accountId: "local")
            )
        }
    }
}


// MARK: - prepare()

extension AppleCalendarUsecaseImpleTests {

    @Test func prepare_whenAccountExists_loadsTags() async throws {
        let usecase = makeUsecase(isIntegrated: true)

        try await confirmation("연동 계정 있을 때 prepare 시 태그 로드", expectedCount: 1) { confirm in
            spyAppearanceStore.didApplyTags = { confirm() }
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func prepare_whenNoAccount_doesNotLoadTags() async throws {
        let usecase = makeUsecase(isIntegrated: false)

        try await confirmation("연동 계정 없을 때 prepare 시 태그 미로드", expectedCount: 0) { confirm in
            spyAppearanceStore.didApplyTags = { confirm() }
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func prepare_whenCalledMultipleTimes_onlyLatestSubscriptionIsActive() async throws {
        let usecase = makeUsecase()

        usecase.prepare()
        usecase.prepare()

        var applyCount = 0
        spyAppearanceStore.didApplyTags = { applyCount += 1 }

        sendIntegration(true)
        try await Task.sleep(for: .milliseconds(100))

        #expect(applyCount == 1)
    }
}


// MARK: - integrationStatusChanged 반응

extension AppleCalendarUsecaseImpleTests {

    @Test func integration_whenConnected_loadsTags() async throws {
        let usecase = makeUsecase()
        usecase.prepare()

        try await confirmation("연동 시 태그 로드", expectedCount: 1) { confirm in
            spyAppearanceStore.didApplyTags = { confirm() }
            sendIntegration(true)
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func integration_whenConnected_setsInitialOffTagIds() async throws {
        let expect = expectConfirm("신규 연동 시 모든 태그를 off 처리")
        expect.count = 2
        let usecase = makeUsecase()

        let offIdsList = try await outputs(expect, for: stubEventTagUsecase.offEventTagIdsOnCalendar()) {
            usecase.prepare()
            sendIntegration(true)
            try await Task.sleep(for: .milliseconds(100))
        }

        let appleOffIds = offIdsList.last?.filter { $0.externalServiceId == AppleCalendarService.id } ?? []
        #expect(appleOffIds.count == stubRepository.stubCalendarTags.count)
    }

    @Test func integration_whenDisconnected_clearsTags() async throws {
        let usecase = makeUsecase(isIntegrated: true)
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        #expect(spyAppearanceStore.tags != nil)

        sendIntegration(false)
        try await Task.sleep(for: .milliseconds(100))

        #expect(spyAppearanceStore.tags == nil)
    }

    @Test func integration_whenDisconnected_removesOffTagIds() async throws {
        let expect = expectConfirm("연동 해제 시 off 처리된 태그 ID 정리")
        expect.count = 2
        let usecase = makeUsecase(isIntegrated: false)

        let tagId = AppleCalendar.Tag(id: "cal:0", name: "Calendar 0", colorHex: nil).tagId
        stubEventTagUsecase.toggleEventTagIsOnCalendar(tagId)

        let offIdsList = try await outputs(expect, for: stubEventTagUsecase.offEventTagIdsOnCalendar()) {
            usecase.prepare()
            sendIntegration(false)
        }

        let hasAppleOffId = offIdsList.map { ids in
            ids.contains(where: { $0.externalServiceId == AppleCalendarService.id })
        }
        #expect(hasAppleOffId == [true, false])
    }

    @Test func integration_whenDisconnected_resetsCacheOnRepository() async throws {
        let usecase = makeUsecase(isIntegrated: true)
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        sendIntegration(false)
        try await Task.sleep(for: .milliseconds(200))

        #expect(stubRepository.didResetCache == true)
    }
}


// MARK: - calendarTags 스트림

extension AppleCalendarUsecaseImpleTests {

    @Test func calendarTags_reflectsLoadedTags() async throws {
        let expect = expectConfirm("태그 로드 후 스트림 반영")
        expect.count = 2

        let usecase = makeUsecase(isIntegrated: true)
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(tagLists.last?.count == stubRepository.stubCalendarTags.count)
    }

    @Test func calendarTags_whenDisconnected_emitsEmpty() async throws {
        let expect = expectConfirm("연동 해제 시 빈 배열 방출")
        expect.count = 3

        let usecase = makeUsecase(isIntegrated: true)
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
            sendIntegration(false)
            try await Task.sleep(for: .milliseconds(100))
        }

        let counts = tagLists.map { $0.count }
        #expect(counts.last == 0)
    }
}


// MARK: - refreshEvents()

extension AppleCalendarUsecaseImpleTests {

    @Test func refreshEvents_loadsAndEmitsEvents() async throws {
        let period: Range<TimeInterval> = 0..<100
        stubRepository.stubEvents = (0..<5).map { i in
            .init(
                eventId: "event:\(i)",
                calendarId: "cal:0",
                name: "Event \(i)",
                eventTime: .period(TimeInterval(i)..<TimeInterval(i + 1))
            )
        }
        let expect = expectConfirm("이벤트 로드 후 스트림 반영")
        expect.count = 2

        let usecase = makeUsecase(isIntegrated: true)
        let eventLists = try await outputs(expect, for: usecase.events(in: period)) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
            usecase.refreshEvents(in: period)
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(eventLists.last?.count == 5)
    }

    @Test func events_returnsOnlyEventsOverlappingPeriod() async throws {
        stubRepository.stubEvents = (0..<10).map { i in
            .init(
                eventId: "event:\(i)",
                calendarId: "cal:0",
                name: "Event \(i)",
                eventTime: .period(TimeInterval(i)..<TimeInterval(i + 1))
            )
        }

        let usecase = makeUsecase(isIntegrated: true)
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))
        usecase.refreshEvents(in: 0..<10)
        try await Task.sleep(for: .milliseconds(100))

        var emitted: [[AppleCalendar.Event]] = []
        let sub = usecase.events(in: 3..<7).sink { emitted.append($0) }
        try await Task.sleep(for: .milliseconds(50))
        sub.cancel()

        let ids = emitted.last?.map { $0.eventId }.sorted() ?? []
        #expect(ids == ["event:3", "event:4", "event:5", "event:6"])
    }
}


// MARK: - Stubs

private final class PrivateStubIntegrationUsecase: ExternalCalendarIntegrationUsecase, @unchecked Sendable {

    private let accountsSubject = CurrentValueSubject<[String: [ExternalServiceAccountinfo]], Never>([:])
    let statusSubject = PassthroughSubject<ExternalCalendarIntegrationStatus, Never>()

    func setAccounts(_ accounts: [ExternalServiceAccountinfo]) {
        let map = accounts.reduce(into: [String: [ExternalServiceAccountinfo]]()) { dict, acc in
            dict[acc.serviceIdentifier, default: []].append(acc)
        }
        accountsSubject.send(map)
    }

    func prepareIntegratedAccounts() async throws {}
    func integrate(external service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo { fatalError() }
    func stopIntegrate(external service: any ExternalCalendarService, accountId: String) async throws {}
    func handleAuthenticationResultOrNot(open url: URL) -> Bool { false }

    var integratedServiceAccounts: AnyPublisher<[String: [ExternalServiceAccountinfo]], Never> {
        accountsSubject.eraseToAnyPublisher()
    }

    var integrationStatusChanged: AnyPublisher<ExternalCalendarIntegrationStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    func currentIntegratedAccounts() -> [ExternalServiceAccountinfo] {
        accountsSubject.value.values.flatMap { $0 }
    }
}


private final class SpyAppleCalendarViewAppearanceStore: AppleCalendarViewAppearanceStore, @unchecked Sendable {

    var tags: [AppleCalendar.Tag]?
    var didApplyTags: (() -> Void)?

    func applyCalendarTags(_ tags: [AppleCalendar.Tag]) {
        self.tags = tags
        didApplyTags?()
    }

    func clearCalendarTags() {
        tags = nil
    }
}
