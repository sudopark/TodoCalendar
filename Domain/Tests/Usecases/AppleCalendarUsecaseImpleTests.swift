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


// MARK: - isCalendarWritable

extension AppleCalendarUsecaseImpleTests {

    @Test func usecase_whenCalendarIsReadOnly_isCalendarWritableIsFalse() async throws {
        // given
        let expect = expectConfirm("읽기 전용 캘린더는 isCalendarWritable이 false")
        expect.count = 2
        let readOnlyTag = AppleCalendar.Tag(id: "cal:0", name: "Calendar 0", colorHex: nil)
            |> \.isWritable .~ false
        stubRepository.stubCalendarTags = [readOnlyTag]
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let results = try await outputs(expect, for: usecase.isCalendarWritable("cal:0")) {
            usecase.prepare()
        }

        // then
        let writable = try #require(results.last)
        #expect(writable == false)
    }

    @Test func usecase_whenCalendarTagIsMissing_isCalendarWritableIsNil() async throws {
        // given
        let expect = expectConfirm("존재하지 않는 캘린더는 isCalendarWritable이 nil")
        expect.count = 2
        stubRepository.stubCalendarTags = [
            AppleCalendar.Tag(id: "cal:0", name: "Calendar 0", colorHex: nil)
        ]
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let results = try await outputs(expect, for: usecase.isCalendarWritable("cal:missing")) {
            usecase.prepare()
        }

        // then
        let writable = try #require(results.last)
        #expect(writable == nil)
    }

    @Test func usecase_whenTagHasNoWritabilityYet_isCalendarWritableIsNil() async throws {
        // given
        let expect = expectConfirm("판정 전 태그는 isCalendarWritable이 nil")
        expect.count = 2
        stubRepository.stubCalendarTags = [
            AppleCalendar.Tag(id: "cal:0", name: "Calendar 0", colorHex: nil)
        ]
        let usecase = makeUsecase(isIntegrated: true)

        // when
        let results = try await outputs(expect, for: usecase.isCalendarWritable("cal:0")) {
            usecase.prepare()
        }

        // then
        let writable = try #require(results.last)
        #expect(writable == nil)
    }
}


// MARK: - updateEvent / removeEvent

extension AppleCalendarUsecaseImpleTests {

    private func seedSharedCache(_ usecase: AppleCalendarUsecaseImple, in period: Range<TimeInterval>) async throws {
        usecase.prepare()
        usecase.refreshEvents(in: period)
        try await Task.sleep(for: .milliseconds(100))
    }

    private func cachedEvents() -> [String: AppleCalendar.Event] {
        stubStore.value(
            [String: AppleCalendar.Event].self, key: ShareDataKeys.appleCalendarEvents.rawValue
        ) ?? [:]
    }

    @Test func usecase_updateNonRepeatingEvent_replacesSharedCacheEntry() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 1))
        try await seedSharedCache(usecase, in: 0..<1)

        var updatedOrigin = AppleCalendar.EventOrigin(
            eventId: "event:0", originalEventId: "event:0",
            calendarId: "cal:0", name: "Updated Name", eventTime: .period(0..<1)
        )
        updatedOrigin.isRepeating = false
        stubRepository.stubUpdatedOrigin = updatedOrigin

        // when
        _ = try await usecase.updateEvent("event:0", params: .init(), scope: .thisEventOnly)

        // then
        #expect(cachedEvents()["event:0"]?.name == "Updated Name")
    }

    @Test func usecase_updateRepeatingEvent_refreshesCachedPeriod() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 3))
        try await seedSharedCache(usecase, in: 0..<3)

        var repeatingOrigin = AppleCalendar.EventOrigin(
            eventId: "event:0", originalEventId: "event:0",
            calendarId: "cal:0", name: "Repeating Updated", eventTime: .period(0..<1)
        )
        repeatingOrigin.isRepeating = true
        stubRepository.stubUpdatedOrigin = repeatingOrigin
        stubRepository.didLoadEventsIn = nil

        // when
        _ = try await usecase.updateEvent("event:0#occ:0", params: .init(), scope: .thisAndFuture)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(stubRepository.didLoadEventsIn == 0..<3)
    }

    @Test func usecase_updateRepeatingEvent_ignoresScopeAndRefreshesCachedPeriod() async throws {
        // given - scope 가 thisEventOnly 여도 대상이 반복 회차면 재조회 경로를 타야 한다
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 3))
        try await seedSharedCache(usecase, in: 0..<3)

        var repeatingOrigin = AppleCalendar.EventOrigin(
            eventId: "event:0", originalEventId: "event:0",
            calendarId: "cal:0", name: "Repeating Updated", eventTime: .period(0..<1)
        )
        repeatingOrigin.isRepeating = true
        stubRepository.stubUpdatedOrigin = repeatingOrigin
        stubRepository.didLoadEventsIn = nil

        // when
        _ = try await usecase.updateEvent("event:0#occ:0", params: .init(), scope: .thisEventOnly)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(stubRepository.didLoadEventsIn == 0..<3)
    }

    @Test func usecase_updateRepeatingOccurrence_whenDetachedIntoNonRepeating_stillRefreshesCachedPeriod() async throws {
        // given - "이번만" 수정은 회차를 시리즈에서 떼어내 결과가 비반복이 된다.
        // 재조회가 필요한 건 회차가 빠진 원본 시리즈 쪽이라 결과로 판단하면 안 된다
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 3))
        try await seedSharedCache(usecase, in: 0..<3)

        var detachedOrigin = AppleCalendar.EventOrigin(
            eventId: "event:0", originalEventId: "event:0",
            calendarId: "cal:0", name: "Detached", eventTime: .period(0..<1)
        )
        detachedOrigin.isRepeating = false
        stubRepository.stubUpdatedOrigin = detachedOrigin
        stubRepository.didLoadEventsIn = nil

        // when
        _ = try await usecase.updateEvent("event:0#occ:0", params: .init(), scope: .thisEventOnly)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(stubRepository.didLoadEventsIn == 0..<3)
    }

    @Test func usecase_removeEvent_removesFromSharedCache() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 3))
        try await seedSharedCache(usecase, in: 0..<3)

        // when
        try await usecase.removeEvent("event:0", scope: .thisEventOnly)

        // then
        #expect(cachedEvents()["event:0"] == nil)
    }

    @Test func usecase_removeRepeatingEvent_thisAndFuture_refreshesCachedPeriod() async throws {
        // given - EventKit 삭제는 N개 회차를 지우지만 캐시는 단건 키만 제거해 나머지 회차가 남는다.
        // 경계가 아닌 중간 이벤트(event:1)를 지워 나머지 캐시(event:0, event:2)의 기간이 그대로 0..<3 유지되게 한다
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 3))
        try await seedSharedCache(usecase, in: 0..<3)
        stubRepository.didLoadEventsIn = nil

        // when
        try await usecase.removeEvent("event:1", scope: .thisAndFuture)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(stubRepository.didLoadEventsIn == 0..<3)
    }

    @Test func usecase_whenRepositoryFails_updateThrowsAndKeepsCache() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 1))
        try await seedSharedCache(usecase, in: 0..<1)
        stubRepository.shouldFailUpdate = true

        // when
        await #expect(throws: (any Error).self) {
            _ = try await usecase.updateEvent("event:0", params: .init(), scope: .thisEventOnly)
        }

        // then
        #expect(cachedEvents()["event:0"]?.name == "Event 0")
    }

    @Test func usecase_whenRepositoryFails_removeThrowsAndKeepsCache() async throws {
        // given
        let usecase = makeUsecase(isIntegrated: true, stubEvents: makeStubEvents(count: 1))
        try await seedSharedCache(usecase, in: 0..<1)
        stubRepository.shouldFailRemove = true

        // when
        await #expect(throws: (any Error).self) {
            try await usecase.removeEvent("event:0", scope: .thisEventOnly)
        }

        // then
        #expect(cachedEvents()["event:0"]?.name == "Event 0")
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
    func reauthenticate(
        external service: any ExternalCalendarService, accountId: String
    ) async throws -> ExternalServiceAccountinfo { fatalError() }
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
