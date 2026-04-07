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

    private func makeUsecase(
        isIntegrated: Bool = false,
        stubEvents: [AppleCalendar.Event] = []
    ) -> AppleCalendarUsecaseImple {
        if isIntegrated {
            let account = ExternalServiceAccountinfo(AppleCalendarService.id, email: "local")
            stubIntegrationUsecase.setAccounts([account])
        }
        stubRepository.stubEvents = stubEvents
        return .init(
            appleService: appleService,
            integrationUsecase: stubIntegrationUsecase,
            repository: stubRepository,
            eventTagUsecase: stubEventTagUsecase,
            appearanceStore: spyAppearanceStore,
            sharedDataStore: stubStore
        )
    }

    private func makeStubEvents(count: Int) -> [AppleCalendar.Event] {
        return (0..<count).map { i in
            AppleCalendar.Event(
                eventId: "event:\(i)",
                originalEventId: "event:\(i)",
                calendarId: "cal:0",
                name: "Event \(i)",
                eventTime: .period(TimeInterval(i)..<TimeInterval(i + 1))
            )
        }
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
        // given
        let expect = expectConfirm("연동 계정 있을 때 prepare 시 태그 로드")
        expect.count = 2
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
        }

        // then
        #expect(tagLists.last?.count == stubRepository.stubCalendarTags.count)
    }

    @Test func prepare_whenNoAccount_doesNotLoadTags() async throws {
        // given
        let expect = expectConfirm("연동 계정 없을 때 prepare 시 태그 미로드")
        let usecase = makeUsecase(isIntegrated: false)

        // when
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
        }

        // then
        #expect(tagLists.last?.isEmpty == true)
    }
}


// MARK: - integrationStatusChanged 반응

extension AppleCalendarUsecaseImpleTests {

    @Test func integration_whenConnected_loadsTags() async throws {
        // given
        let expect = expectConfirm("연동 시 태그 로드")
        expect.count = 2
        let usecase = makeUsecase()

        // when
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            self.sendIntegration(true)
        }

        // then
        #expect(tagLists.last?.isEmpty == false)
    }

    @Test func integration_whenDisconnected_clearsTags() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: true)
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        sendIntegration(false)
        try await Task.sleep(for: .milliseconds(100))

        // then
        #expect(spyAppearanceStore.tags == nil)
    }

    @Test func integration_whenDisconnected_removesOffTagIds() async throws {
        // given
        let expect = expectConfirm("연동 해제 시 off 처리된 태그 ID 정리")
        expect.count = 2
        let usecase = makeUsecase(isIntegrated: false)

        let tagId = AppleCalendar.Tag(id: "cal:0", name: "Calendar 0", colorHex: nil).tagId
        stubEventTagUsecase.toggleEventTagIsOnCalendar(tagId)

        // when
        let offIdsList = try await outputs(expect, for: stubEventTagUsecase.offEventTagIdsOnCalendar()) {
            usecase.prepare()
            self.sendIntegration(false)
        }

        // then
        let hasAppleOffId = offIdsList.map { ids in
            ids.contains(where: { $0.externalServiceId == AppleCalendarService.id })
        }
        #expect(hasAppleOffId == [true, false])
    }

    @Test func integration_whenDisconnected_resetsCacheOnRepository() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: true)
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        sendIntegration(false)
        try await Task.sleep(for: .milliseconds(200))

        // then
        #expect(stubRepository.didResetCache == true)
    }
}


// MARK: - calendarTags 스트림

extension AppleCalendarUsecaseImpleTests {

    @Test func calendarTags_reflectsLoadedTags() async throws {
        // given
        let expect = expectConfirm("태그 로드 후 스트림 반영")
        expect.count = 2
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
        }

        // then
        #expect(tagLists.last?.count == stubRepository.stubCalendarTags.count)
    }

    @Test func calendarTags_whenDisconnected_emitsEmpty() async throws {
        // given
        let expect = expectConfirm("연동 해제 시 빈 배열 방출")
        expect.count = 3
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
            self.sendIntegration(false)
        }

        // then
        let counts = tagLists.map { $0.count }
        #expect(counts.last == 0)
    }
}


// MARK: - refreshCalendarTags()

extension AppleCalendarUsecaseImpleTests {

    @Test func refreshCalendarTags_whenNotIntegrated_doesNotUpdateTags() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: false)
        usecase.prepare()

        // when
        usecase.refreshCalendarTags()
        try await Task.sleep(for: .milliseconds(100))

        // then
        #expect(spyAppearanceStore.tags == nil)
    }

    @Test func refreshCalendarTags_whenIntegrated_updatesTags() async throws {
        // given
        let expect = expectConfirm("연동 시 refreshCalendarTags가 태그 반영")
        expect.count = 3
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            usecase.refreshCalendarTags()
        }

        // then
        #expect(tagLists.last?.count == stubRepository.stubCalendarTags.count)
        #expect(spyAppearanceStore.tags?.isEmpty == false)
    }
}


// MARK: - refreshEvents()

extension AppleCalendarUsecaseImpleTests {

    @Test func refreshEvents_loadsAndEmitsEvents() async throws {
        // given
        let period: Range<TimeInterval> = 0..<100
        let stubEvents = makeStubEvents(count: 5)
        let expect = expectConfirm("이벤트 로드 후 스트림 반영")
        expect.count = 2
        let usecase = makeUsecase(isIntegrated: true, stubEvents: stubEvents)

        // when
        let eventLists = try await outputs(expect, for: usecase.events(in: period)) {
            usecase.prepare()
            usecase.refreshEvents(in: period)
        }

        // then
        #expect(eventLists.last?.count == 5)
    }

    @Test func events_returnsOnlyEventsOverlappingPeriod() async throws {
        // given
        let allEvents = makeStubEvents(count: 10)
        let usecase = makeUsecase(isIntegrated: true, stubEvents: allEvents)

        // when
        usecase.prepare()
        usecase.refreshEvents(in: 0..<10)
        try await Task.sleep(for: .milliseconds(100))

        var emitted: [[AppleCalendar.Event]] = []
        let sub = usecase.events(in: 3..<7).sink { emitted.append($0) }
        try await Task.sleep(for: .milliseconds(50))
        sub.cancel()

        // then
        let ids = emitted.last?.map { $0.eventId }.sorted() ?? []
        #expect(ids == ["event:3", "event:4", "event:5", "event:6"])
    }

    @Test func refreshEvents_whenNotIntegrated_doesNotLoadEvents() async throws {
        // given
        let period: Range<TimeInterval> = 0..<100
        let usecase = makeUsecase(isIntegrated: false, stubEvents: makeStubEvents(count: 5))
        usecase.prepare()

        // when
        usecase.refreshEvents(in: period)
        try await Task.sleep(for: .milliseconds(100))

        // then
        #expect(stubRepository.didLoadEvents == false)
    }

    @Test func refreshEvents_whenIntegratedAfterRefreshCall_loadsEventsAutomatically() async throws {
        // given
        let period: Range<TimeInterval> = 0..<100
        let stubEvents = makeStubEvents(count: 3)
        let expect = expectConfirm("연동 후 자동으로 이벤트 로드")
        expect.count = 2
        let usecase = makeUsecase(isIntegrated: false, stubEvents: stubEvents)
        usecase.prepare()

        // when
        let eventLists = try await outputs(expect, for: usecase.events(in: period)) {
            usecase.refreshEvents(in: period)
            self.sendIntegration(true)
        }

        // then
        #expect(eventLists.last?.count == 3)
    }

    @Test func refreshEvents_removesDeletedEventsInPeriod() async throws {
        // given - 0..<5 범위에 5개 이벤트 로드
        let initialEvents = makeStubEvents(count: 5)
        let usecase = makeUsecase(isIntegrated: true, stubEvents: initialEvents)
        usecase.prepare()
        usecase.refreshEvents(in: 0..<5)
        try await Task.sleep(for: .milliseconds(100))

        // when - 같은 범위 재조회 시 event:0 삭제된 상태
        stubRepository.stubEvents = Array(initialEvents.dropFirst())
        let expect = expectConfirm("삭제된 이벤트 제거 후 스트림 반영")
        expect.count = 2
        let eventLists = try await outputs(expect, for: usecase.events(in: 0..<5)) {
            usecase.refreshEvents(in: 0..<5)
        }

        // then
        let ids = eventLists.last?.map { $0.eventId }.sorted() ?? []
        #expect(ids == ["event:1", "event:2", "event:3", "event:4"])
    }
}


// MARK: - eventOrigin

extension AppleCalendarUsecaseImpleTests {

    @Test func eventOrigin_returnsOriginFromRepository() async throws {
        // given
        let expect = expectConfirm("이벤트 오리진 반환")
        var origin = AppleCalendar.EventOrigin(
            eventId: "event:0", originalEventId: "event:0",
            calendarId: "cal:0", name: "Test", eventTime: .at(100)
        )
        origin.recurrenceRules = ["RRULE:FREQ=DAILY;INTERVAL=1"]
        origin.attendees = [.init(name: "Alice", email: "alice@test.com")]
        origin.url = "https://example.com"
        origin.notes = "some notes"
        stubRepository.stubEventOrigin = origin
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let result = try await firstOutput(expect, for: usecase.eventOrigin(id: "event:0"))

        // then
        let loaded = try #require(result)
        #expect(loaded?.eventId == "event:0")
        #expect(loaded?.recurrenceRules == ["RRULE:FREQ=DAILY;INTERVAL=1"])
        #expect(loaded?.attendees.first?.name == "Alice")
        #expect(loaded?.url == "https://example.com")
        #expect(loaded?.notes == "some notes")
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
