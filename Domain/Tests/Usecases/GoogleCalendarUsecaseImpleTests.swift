//
//  GoogleCalendarUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

@testable import Domain

final class GoogleCalendarUsecaseImpleTests: PublisherWaitable {

    private let spyViewAppearanceStore = SpyGoogleCalendarViewAppearanceStore()
    private let stubStore = SharedDataStore()
    private let service = GoogleCalendarService(scopes: [.readOnly])
    private let stubEventTagUsecase = StubEventTagUsecase()
    private let stubIntegrationUsecase = PrivateStubIntegrationUsecase()
    private let stubRepositoryPool = PrivateStubRepositoryPool()

    var cancelBag: Set<AnyCancellable>! = []

    private func updateAccount(email: String, integrated: Bool, isNew: Bool = false) {
        let serviceId = service.identifier
        if integrated {
            var account = ExternalServiceAccountinfo(serviceId, email: email)
            if isNew { account.intergrationTime = Date() }
            let current = stubIntegrationUsecase.currentIntegratedAccounts(for: serviceId)
            stubIntegrationUsecase.setAccounts(current + [account])
            stubIntegrationUsecase.statusSubject.send(
                .integrated(serviceId: serviceId, account: account)
            )
        } else {
            let current = stubIntegrationUsecase.currentIntegratedAccounts(for: serviceId)
            stubIntegrationUsecase.setAccounts(current.filter { $0.email != email })
            stubIntegrationUsecase.statusSubject.send(
                .disconnected(serviceId: serviceId, accountId: email)
            )
        }
    }

    private func makeUsecase(
        accounts: [String] = [],
        defaultRepo: PrivateStubRepository = .init()
    ) -> GoogleCalendarUsecaseImple {
        stubRepositoryPool.setDefaultRepository(defaultRepo)
        accounts.forEach { updateAccount(email: $0, integrated: true) }
        return .init(
            googleService: GoogleCalendarService(scopes: [.readOnly]),
            integrationUsecase: stubIntegrationUsecase,
            repositoryPool: stubRepositoryPool,
            eventTagUsecase: stubEventTagUsecase,
            appearanceStore: spyViewAppearanceStore,
            sharedDataStore: stubStore
        )
    }
}


// MARK: - 역할 1: prepare()

extension GoogleCalendarUsecaseImpleTests {

    @Test func prepare_whenAccountExists_loadsColorsAndTags() async throws {
        let usecase = makeUsecase(accounts: ["account@google.com"])

        try await confirmation("계정 연동 상태에서 prepare 시 색상/태그 로드", expectedCount: 2) { confirm in
            spyViewAppearanceStore.didUpdateColors = { _ in confirm() }
            spyViewAppearanceStore.didUpdateTags = { confirm() }
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func prepare_whenNoAccount_doesNotLoadColorsOrTags() async throws {
        let usecase = makeUsecase()

        try await confirmation(
            "계정 미연동 상태에서 prepare 시 색상/태그 미로드",
            expectedCount: 0
        ) { confirm in
            spyViewAppearanceStore.didUpdateColors = { _ in confirm() }
            spyViewAppearanceStore.didUpdateTags = { confirm() }
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func prepare_whenCalledMultipleTimes_onlyLatestSubscriptionIsActive() async throws {
        let usecase = makeUsecase()

        usecase.prepare()
        usecase.prepare()

        var colorUpdateCount = 0
        spyViewAppearanceStore.didUpdateColors = { _ in colorUpdateCount += 1 }

        updateAccount(email: "new@google.com", integrated: true, isNew: true)
        try await Task.sleep(for: .milliseconds(100))

        // 구독이 중복되지 않으므로 1회만 업데이트
        #expect(colorUpdateCount == 1)
    }
}


// MARK: - 역할 2: 연동 상태 반응

extension GoogleCalendarUsecaseImpleTests {

    @Test func integration_whenNewAccountConnected_loadsColorsAndTags() async throws {
        let usecase = makeUsecase()
        usecase.prepare()

        try await confirmation("새 계정 연동 시 색상/태그 로드", expectedCount: 2) { confirm in
            spyViewAppearanceStore.didUpdateColors = { _ in confirm() }
            spyViewAppearanceStore.didUpdateTags = { confirm() }
            self.updateAccount(email: "new@google.com", integrated: true, isNew: true)
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func integration_whenNewAccountConnected_setsInitialOffTagIds() async throws {
        let expect = expectConfirm("새 계정 연동 시 비활성 태그(isSelected != true) off 처리")
        expect.count = 2
        let usecase = makeUsecase()

        let offIdsList = try await outputs(expect, for: stubEventTagUsecase.offEventTagIdsOnCalendar()) {
            usecase.prepare()
            self.updateAccount(email: "new@google.com", integrated: true, isNew: true)
            try await Task.sleep(for: .milliseconds(100))
        }

        let externalOffIds = offIdsList.last?.filter { $0.externalServiceId != nil } ?? []
        #expect(externalOffIds == [.externalCalendar(serviceId: GoogleCalendarService.id, id: "tag2")])
    }

    @Test func integration_whenAccountDisconnected_clearsColorsTagsAndEvents() async throws {
        let usecase = makeUsecase(accounts: ["account@google.com"])
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))
        usecase.refreshEvents(in: 0..<100)
        try await Task.sleep(for: .milliseconds(100))

        #expect(spyViewAppearanceStore.color != nil)

        self.updateAccount(email: "account@google.com", integrated: false)
        try await Task.sleep(for: .milliseconds(300))

        #expect(spyViewAppearanceStore.color == nil)
        #expect(spyViewAppearanceStore.tagMaps.isEmpty)
    }

    @Test func integration_whenAccountDisconnected_removesOffTagIds() async throws {
        let expect = expectConfirm("계정 연동 해제 시 off 처리된 태그 ID 정리")
        expect.count = 2
        let usecase = makeUsecase(accounts: ["account@google.com"])
        stubEventTagUsecase.toggleEventTagIsOnCalendar(
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag1")
        )
        stubEventTagUsecase.toggleEventTagIsOnCalendar(
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag2")
        )

        let offIdsList = try await outputs(expect, for: stubEventTagUsecase.offEventTagIdsOnCalendar()) {
            usecase.prepare()
            self.updateAccount(email: "account@google.com", integrated: false)
        }

        let hasGoogleOffId = offIdsList.map { ids in
            ids.contains(where: { $0.externalServiceId == GoogleCalendarService.id })
        }
        #expect(hasGoogleOffId == [true, false])
    }

    @Test func integration_whenOneAccountDisconnected_otherAccountRemainsIntact() async throws {
        let repo1 = PrivateStubRepository(customCalendarsStubbing: [.init(id: "cal-a", name: "A")])
        let repo2 = PrivateStubRepository(customCalendarsStubbing: [.init(id: "cal-b", name: "B")])
        stubRepositoryPool.setRepository(repo1, for: "account1@google.com")
        stubRepositoryPool.setRepository(repo2, for: "account2@google.com")

        let usecase = makeUsecase(accounts: ["account1@google.com", "account2@google.com"])

        let expect = expectConfirm("한 계정 해제 시 나머지 계정 태그 유지")
        expect.count = 4  // [], [cal-a], [cal-a, cal-b], [cal-b]

        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
            self.updateAccount(email: "account1@google.com", integrated: false)
            try await Task.sleep(for: .milliseconds(100))
        }

        let finalIds = tagLists.last?.map { $0.id }
        #expect(finalIds == ["cal-b"])
    }
}


// MARK: - 역할 3: 태그 목록

extension GoogleCalendarUsecaseImpleTests {

    @Test func calendarTags_excludesHolidayCalendars() async throws {
        let stub: [GoogleCalendar.Tag] = [
            .init(id: "real", name: "My Calendar"),
            .init(id: "ko.kr.official#holiday@group.v.calendar.google.com", name: "holidays")
        ]
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(customCalendarsStubbing: stub)
        )

        let expect = expectConfirm("태그 목록에서 공휴일 캘린더 제외")
        expect.count = 2

        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
        }

        let idLists = tagLists.map { $0.map { $0.id } }
        #expect(idLists == [[], ["real"]])
    }

    @Test func calendarTags_whenNewAccountIntegrated_includesNewTags() async throws {
        let expect = expectConfirm("새 계정 연동 시 해당 계정의 태그가 추가")
        expect.count = 3
        let usecase = makeUsecase(accounts: ["account@google.com"])

        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
            self.updateAccount(email: "new@google.com", integrated: true, isNew: true)
            try await Task.sleep(for: .milliseconds(100))
        }

        // account@google.com의 태그(tag1, tag2) + new@google.com의 태그(tag1-new, tag2-new) 합산
        let finalNames = Set(tagLists.last?.map { $0.name } ?? [])
        #expect(finalNames == ["tag1", "tag2", "tag1-new", "tag2-new"])
    }

    @Test func calendarTags_withMultipleAccounts_mergesAllAccountTags() async throws {
        let repo1 = PrivateStubRepository(customCalendarsStubbing: [.init(id: "cal-a", name: "A")])
        let repo2 = PrivateStubRepository(customCalendarsStubbing: [.init(id: "cal-b", name: "B")])
        stubRepositoryPool.setRepository(repo1, for: "account1@google.com")
        stubRepositoryPool.setRepository(repo2, for: "account2@google.com")

        let usecase = makeUsecase(accounts: ["account1@google.com", "account2@google.com"])

        let expect = expectConfirm("여러 계정의 태그를 합산하여 제공")
        expect.count = 3  // [], [cal-a], [cal-a, cal-b]

        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
        }

        let finalIds = Set(tagLists.last?.map { $0.id } ?? [])
        #expect(finalIds == ["cal-a", "cal-b"])
    }

    @Test func calendarTags_whenAccountDisconnected_removesItsTags() async throws {
        let expect = expectConfirm("계정 연동 해제 시 해당 계정의 태그 제거")
        expect.count = 3
        let usecase = makeUsecase(accounts: ["account@google.com"])

        let tagLists = try await outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(100))
            self.updateAccount(email: "account@google.com", integrated: false)
        }

        let tagCounts = tagLists.map { $0.count }
        #expect(tagCounts == [0, 2, 0])
        let midTagIds = Set(tagLists[1].map { $0.tagId })
        #expect(midTagIds == [
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag1"),
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag2")
        ])
    }
}


// MARK: - 역할 4: refreshEvents()

extension GoogleCalendarUsecaseImpleTests {

    @Test func refreshEvents_loadsEventsForActiveCalendars() async throws {
        let expect = expectConfirm("활성 캘린더의 이벤트 조회")
        expect.count = 3
        let usecase = makeUsecase(accounts: ["account@google.com"])
        usecase.prepare()

        let eventLists = try await outputs(expect, for: usecase.events(in: 0..<100)) {
            try await Task.sleep(for: .milliseconds(100))
            usecase.refreshEvents(in: 0..<100)
        }

        let eventCounts = eventLists.map { $0.count }
        #expect(eventCounts == [0, 10, 20])
        #expect(eventLists.last?.filter { $0.calendarId == "tag1" }.count == 10)
        #expect(eventLists.last?.filter { $0.calendarId == "tag2" }.count == 10)
    }

    @Test func refreshEvents_doesNotLoadEventsForOffCalendars() async throws {
        let expect = expectConfirm("off 처리된 캘린더는 이벤트 조회 제외")
        expect.count = 2
        let usecase = makeUsecase(accounts: ["account@google.com"])
        stubEventTagUsecase.toggleEventTagIsOnCalendar(
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag1")
        )
        usecase.prepare()

        let eventLists = try await outputs(expect, for: usecase.events(in: 0..<100)) {
            try await Task.sleep(for: .milliseconds(100))
            usecase.refreshEvents(in: 0..<100)
        }

        let calendarIds = Set(eventLists.last?.map { $0.calendarId } ?? [])
        #expect(calendarIds == ["tag2"])
    }

    @Test func refreshEvents_removesDeletedEventsFromStream() async throws {
        let expect = expectConfirm("이벤트 새로고침 시 삭제된 이벤트 제거")
        expect.count = 3
        let mocking = PassthroughSubject<[GoogleCalendar.Event], any Error>()
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(
                customCalendarsStubbing: [.init(id: "tag1", name: "tag1")],
                eventsMocking: mocking
            )
        )
        usecase.prepare()

        let dummyEvents = (0..<5).map { i -> GoogleCalendar.Event in
            .init("\(i)-tag1", "tag1", accountId: "stub@gmail.com", name: "event", colorId: "c", time: .period(0..<10))
        }

        let eventLists = try await outputs(expect, for: usecase.events(in: 0..<20)) {
            try await Task.sleep(for: .milliseconds(100))
            usecase.refreshEvents(in: 0..<20)
            try await Task.sleep(for: .milliseconds(100))
            mocking.send(dummyEvents)
            try await Task.sleep(for: .milliseconds(100))
            mocking.send(dummyEvents.filter { $0.eventId != "2-tag1" })
        }

        let hasEvent2 = eventLists.map { $0.contains(where: { $0.eventId == "2-tag1" }) }
        #expect(hasEvent2 == [false, true, false])
    }

    @Test func refreshEvents_whenAllCalendarsOff_doesNotLoadAnyEvents() async throws {
        let expect = expectConfirm("모든 캘린더 off 시 이벤트 미조회")
        expect.count = 0
        let usecase = makeUsecase(accounts: ["account@google.com"])
        stubEventTagUsecase.toggleEventTagIsOnCalendar(
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag1")
        )
        stubEventTagUsecase.toggleEventTagIsOnCalendar(
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag2")
        )
        usecase.prepare()

        let eventLists = try await outputs(expect, for: usecase.events(in: 0..<100).filter { !$0.isEmpty }) {
            try await Task.sleep(for: .milliseconds(100))
            usecase.refreshEvents(in: 0..<100)
        }

        #expect(eventLists.isEmpty)
    }
}


// MARK: - 역할 5: events() 스트림

extension GoogleCalendarUsecaseImpleTests {

    @Test func events_returnsOnlyEventsOverlappingPeriod() async throws {
        let expect = expectConfirm("기간에 해당하는 이벤트만 반환")
        expect.count = 3
        let usecase = makeUsecase(accounts: ["account@google.com"])
        usecase.prepare()

        let eventLists = try await outputs(expect, for: usecase.events(in: 3..<20)) {
            try await Task.sleep(for: .milliseconds(100))
            usecase.refreshEvents(in: 0..<10)
        }

        let last = eventLists.last
        let tag1Events = last?.filter { $0.calendarId == "tag1" } ?? []
        let tag2Events = last?.filter { $0.calendarId == "tag2" } ?? []
        #expect(tag1Events.map { $0.eventId }.sorted() == (3..<10).map { "event:\($0)-tag1" })
        #expect(tag2Events.map { $0.eventId }.sorted() == (3..<10).map { "event:\($0)-tag2" })
    }

    @Test func events_whenAccountDisconnected_removesItsEvents() async throws {
        let usecase = makeUsecase(accounts: ["account@google.com"])
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))
        usecase.refreshEvents(in: 0..<100)
        try await Task.sleep(for: .milliseconds(100))

        // 이벤트가 로드된 상태에서 구독 시작
        var emittedCounts: [Int] = []
        let sub = usecase.events(in: 0..<100).sink { emittedCounts.append($0.count) }
        try await Task.sleep(for: .milliseconds(50))

        self.updateAccount(email: "account@google.com", integrated: false)
        try await Task.sleep(for: .milliseconds(300))
        sub.cancel()

        // 이벤트가 로드되었다가 연결 해제 후 제거됨을 확인
        #expect(emittedCounts.contains(20))
        #expect(emittedCounts.contains(0))
    }
}


// MARK: - 역할 6: eventDetail()

extension GoogleCalendarUsecaseImpleTests {

    @Test func eventDetail_fetchesFromRepositoryForAccount() async throws {
        let expect = expectConfirm("eventDetail은 해당 계정의 repository에서 조회")
        let usecase = makeUsecase(accounts: ["account@google.com"])

        let origin = try await firstOutput(expect, for: usecase.eventDetail(
            "calendar1", "event1", accountId: "account@google.com", at: .current
        ))

        #expect(origin != nil)
        #expect(origin?.id == "event1")
    }
}


// MARK: - Event 변환 단위 테스트

extension GoogleCalendarUsecaseImpleTests {

    private var dummyAllDayEventOrigin: GoogleCalendar.EventOrigin {
        var raw = GoogleCalendar.EventOrigin(id: "id", summary: "summary")
        raw.start = .init() |> \.date .~ "2023-03-03" |> \.timeZone .~ "Asia/Seoul"
        raw.end = .init() |> \.date .~ "2023-04-03"
        return raw
    }

    private var dummyPeriodEventOrigin: GoogleCalendar.EventOrigin {
        var raw = GoogleCalendar.EventOrigin(id: "id", summary: "summary")
        raw.start = .init() |> \.dateTime .~ "2023-03-05T00:00:00+09:00"
        raw.end = .init() |> \.dateTime .~ "2023-03-06T00:00:00+09:00"
        return raw
    }

    @Test func convertEventRawValue_whenTimeIsAllDay_convertsToEvent() {
        let event = GoogleCalendar.Event(dummyAllDayEventOrigin, "calendar_id", accountId: "stub@gmail.com", "Asia/Seoul")

        #expect(event?.eventId == "id")
        #expect(event?.name == "summary")
        #expect(event?.eventTagId == .externalCalendar(serviceId: GoogleCalendarService.id, id: "calendar_id"))

        let kst = TimeZone(abbreviation: "KST")!
        let lower = "2023-03-03".date(form: "yyyy-MM-dd", timeZoneAbbre: "KST").timeIntervalSince1970
        let upper = "2023-04-03".date(form: "yyyy-MM-dd", timeZoneAbbre: "KST").timeIntervalSince1970
        #expect(event?.eventTime == .allDay(lower..<upper, secondsFromGMT: Double(kst.secondsFromGMT())))
    }

    @Test func convertEventRawValue_whenTimeIsPeriod_convertsToEvent() {
        let event = GoogleCalendar.Event(dummyPeriodEventOrigin, "calendar_id", accountId: "stub@gmail.com", "Asia/Seoul")

        #expect(event?.eventId == "id")
        #expect(event?.name == "summary")
        #expect(event?.eventTagId == .externalCalendar(serviceId: GoogleCalendarService.id, id: "calendar_id"))

        let lower = "2023-03-05T00:00:00+09:00".date(form: "yyyy-MM-dd'T'HH:mm:ssz", timeZoneAbbre: "KST").timeIntervalSince1970
        let upper = "2023-03-06T00:00:00+09:00".date(form: "yyyy-MM-dd'T'HH:mm:ssZ", timeZoneAbbre: "KST").timeIntervalSince1970
        #expect(event?.eventTime == .period(lower..<upper))
    }
}


// MARK: - Stubs

private final class PrivateStubRepositoryPool: GoogleCalendarRepositoryPool, @unchecked Sendable {

    private var defaultRepo: PrivateStubRepository = .init()
    private var repos: [String: PrivateStubRepository] = [:]

    func setDefaultRepository(_ repo: PrivateStubRepository) {
        defaultRepo = repo
    }

    func setRepository(_ repo: PrivateStubRepository, for accountId: String) {
        repos[accountId] = repo
    }

    func repository(for accountId: String) -> any GoogleCalendarRepository {
        return repos[accountId] ?? defaultRepo
    }

    func removeRepository(for accountId: String) {
        repos[accountId] = nil
    }
}


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


private final class PrivateStubRepository: GoogleCalendarRepository, @unchecked Sendable {

    private var stubColors: [GoogleCalendar.Colors]
    private var stubCalendarTags: [[GoogleCalendar.Tag]]
    var eventsMocking: PassthroughSubject<[GoogleCalendar.Event], any Error>?

    init(
        customCalendarsStubbing: [GoogleCalendar.Tag]? = nil,
        eventsMocking: PassthroughSubject<[GoogleCalendar.Event], any Error>? = nil
    ) {
        self.stubColors = [
            .init(
                ownerId: "account@google.com",
                calendars: ["0": .init(foregroundHex: "f0", backgroudHex: "b0")],
                events: ["1": .init(foregroundHex: "f1", backgroudHex: "b1")]
            ),
            .init(
                ownerId: "account@google.com",
                calendars: ["0": .init(foregroundHex: "new-f0", backgroudHex: "new-b0")],
                events: ["1": .init(foregroundHex: "new-f1", backgroudHex: "new-b1")]
            )
        ]
        let defaultTags: [[GoogleCalendar.Tag]] = [
            [
                GoogleCalendar.Tag(id: "tag1", name: "tag1") |> \.isSelected .~ true,
                GoogleCalendar.Tag(id: "tag2", name: "tag2")
            ],
            [
                GoogleCalendar.Tag(id: "tag1", name: "tag1-new") |> \.isSelected .~ true,
                GoogleCalendar.Tag(id: "tag2", name: "tag2-new")
            ]
        ]
        self.stubCalendarTags = customCalendarsStubbing.map { [$0] } ?? defaultTags
        self.eventsMocking = eventsMocking
    }

    func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        guard !stubColors.isEmpty else { return Empty().eraseToAnyPublisher() }
        return Just(stubColors.removeFirst()).mapAsAnyError().eraseToAnyPublisher()
    }

    func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        guard !stubCalendarTags.isEmpty else { return Empty().eraseToAnyPublisher() }
        return Just(stubCalendarTags.removeFirst()).mapAsAnyError().eraseToAnyPublisher()
    }

    func loadEvents(
        _ calendarId: String, in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        if let mocking = eventsMocking {
            return mocking.eraseToAnyPublisher()
        }
        let events = (0..<10).map { i -> GoogleCalendar.Event in
            .init(
                "event:\(i)-\(calendarId)", calendarId,
                accountId: "stub@gmail.com",
                name: "some name", colorId: "color",
                time: .period(period.lowerBound..<period.lowerBound + TimeInterval(i + 1))
            )
        }
        return Just(events).mapAsAnyError().eraseToAnyPublisher()
    }

    func loadEventDetail(
        _ calendarId: String, _ timeZone: String, _ eventId: String
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        let origin = GoogleCalendar.EventOrigin(id: eventId, summary: "some")
        return Just(origin).mapAsAnyError().eraseToAnyPublisher()
    }

    func resetCache() async throws {}
}


private final class SpyGoogleCalendarViewAppearanceStore: GoogleCalendarViewAppearanceStore, @unchecked Sendable {

    var color: GoogleCalendar.Colors?
    var tagMaps: [String: GoogleCalendar.Tag] = [:]

    var didUpdateColors: ((GoogleCalendar.Colors?) -> Void)?
    func applyColors(_ colors: GoogleCalendar.Colors, for accountId: String) {
        color = colors
        didUpdateColors?(colors)
    }

    var didClearColor: (() -> Void)?
    func clearColors(for accountId: String) {
        color = nil
        didClearColor?()
    }

    var didUpdateTags: (() -> Void)?
    func applyCalendarTags(_ tags: [GoogleCalendar.Tag], for accountId: String) {
        tagMaps = tags.asDictionary { $0.id }
        didUpdateTags?()
    }

    func clearCalendarTags(for accountId: String) {
        tagMaps = [:]
    }
}
