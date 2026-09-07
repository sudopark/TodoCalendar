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
    private let service = GoogleCalendarService(scopes: [.readWrite])
    private let stubEventTagUsecase = StubEventTagUsecase()
    private let stubIntegrationUsecase = PrivateStubIntegrationUsecase()
    private let stubRepositoryPool = PrivateStubRepositoryPool()

    var cancelBag: Set<AnyCancellable>! = []

    private func updateAccount(
        email: String, integrated: Bool, isNew: Bool = false, grantedScopes: [String]? = nil
    ) {
        let serviceId = service.identifier
        if integrated {
            var account = ExternalServiceAccountinfo(serviceId, email: email)
            account.grantedScopes = grantedScopes
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
        accountScopes: [String: [String]] = [:],
        defaultRepo: PrivateStubRepository = .init()
    ) -> GoogleCalendarUsecaseImple {
        stubRepositoryPool.setDefaultRepository(defaultRepo)
        accounts.forEach { updateAccount(email: $0, integrated: true, grantedScopes: accountScopes[$0]) }
        return .init(
            googleService: GoogleCalendarService(scopes: [.readWrite]),
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

    /// #934 — 라이브액티비티가 팔레트(colorId→hex)를 읽을 수 있어야 이벤트 개별 색을 반영한다.
    @Test func prepare_whenAccountExists_storesColorsInSharedDataStore() async throws {
        // given
        let usecase = makeUsecase(accounts: ["account@google.com"])

        // when
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // then
        let colors = stubStore.value(
            [String: GoogleCalendar.Colors].self, key: ShareDataKeys.googleCalendarColors.rawValue
        )
        #expect(colors?["account@google.com"] != nil)
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

    /// #934 — 로그아웃한 계정의 팔레트가 SharedDataStore 에 남으면 라이브액티비티가 옛 색을 계속 쓴다.
    @Test func integration_whenAccountDisconnected_removesColorsFromSharedDataStore() async throws {
        // given
        let usecase = makeUsecase(accounts: ["account@google.com"])
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))
        let seeded = stubStore.value(
            [String: GoogleCalendar.Colors].self, key: ShareDataKeys.googleCalendarColors.rawValue
        )
        #expect(seeded?["account@google.com"] != nil)

        // when
        self.updateAccount(email: "account@google.com", integrated: false)
        try await Task.sleep(for: .milliseconds(300))

        // then
        let cleared = stubStore.value(
            [String: GoogleCalendar.Colors].self, key: ShareDataKeys.googleCalendarColors.rawValue
        )
        #expect(cleared?["account@google.com"] == nil)
    }

    @Test func integration_whenOneAccountDisconnected_otherAccountColorsRemainIntact() async throws {
        // given
        let repo1 = PrivateStubRepository(customCalendarsStubbing: [.init(id: "cal-a", name: "A")])
        let repo2 = PrivateStubRepository(customCalendarsStubbing: [.init(id: "cal-b", name: "B")])
        stubRepositoryPool.setRepository(repo1, for: "account1@google.com")
        stubRepositoryPool.setRepository(repo2, for: "account2@google.com")
        let usecase = makeUsecase(accounts: ["account1@google.com", "account2@google.com"])
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        self.updateAccount(email: "account1@google.com", integrated: false)
        try await Task.sleep(for: .milliseconds(100))

        // then
        let colors = stubStore.value(
            [String: GoogleCalendar.Colors].self, key: ShareDataKeys.googleCalendarColors.rawValue
        )
        #expect(colors?["account1@google.com"] == nil)
        #expect(colors?["account2@google.com"] != nil)
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


// MARK: - 역할 7: eventWritePermission() — 캘린더 층 우선 판정

extension GoogleCalendarUsecaseImpleTests {

    private var writableScope: [String] { [GoogleCalendarService.Scope.readWrite.rawValue] }

    @Test func eventWritePermission_whenAccountLacksWriteScope_needsReauthentication() async throws {
        // given — 캘린더는 owner(쓰기 가능)지만 계정에 쓰기 scope 가 없음
        let tag = GoogleCalendar.Tag(id: "cal1", name: "cal1") |> \.accessRole .~ .owner
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(customCalendarsStubbing: [tag])
        )
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        let expect = expectConfirm("캘린더는 쓰기 가능 → 계정 scope 없어 재인증 필요")
        let permission = try await firstOutput(expect, for: usecase.eventWritePermission(
            accountId: "account@google.com", calendarId: "cal1"
        ))

        // then
        #expect(permission == .needReauthentication)
    }

    @Test func eventWritePermission_whenAccountLacksWriteScopeAndCalendarReadOnly_readOnlyCalendarTakesPrecedence() async throws {
        // given — 계정 scope 없음 + 캘린더도 reader(둘 다 실패). 캘린더 층이 먼저 판정한다
        let tag = GoogleCalendar.Tag(id: "cal1", name: "cal1") |> \.accessRole .~ .reader
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(customCalendarsStubbing: [tag])
        )
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        let expect = expectConfirm("계정·캘린더 모두 쓰기 불가 → 재인증 아니라 readOnlyCalendar")
        let permission = try await firstOutput(expect, for: usecase.eventWritePermission(
            accountId: "account@google.com", calendarId: "cal1"
        ))

        // then
        #expect(permission == .readOnlyCalendar)
    }

    @Test func eventWritePermission_whenAccountWritableButCalendarReadOnly_readOnlyCalendar() async throws {
        // given — 계정은 쓰기 scope 보유, 캘린더는 reader(읽기 전용)
        let tag = GoogleCalendar.Tag(id: "cal1", name: "cal1") |> \.accessRole .~ .reader
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            accountScopes: ["account@google.com": writableScope],
            defaultRepo: .init(customCalendarsStubbing: [tag])
        )
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        let expect = expectConfirm("계정은 쓰기 가능하나 캘린더가 읽기전용")
        let permission = try await firstOutput(expect, for: usecase.eventWritePermission(
            accountId: "account@google.com", calendarId: "cal1"
        ))

        // then
        #expect(permission == .readOnlyCalendar)
    }

    @Test func eventWritePermission_whenAccountWritableAndCalendarOwner_writable() async throws {
        // given — 계정 쓰기 scope + 캘린더 owner 모두 충족
        let tag = GoogleCalendar.Tag(id: "cal1", name: "cal1") |> \.accessRole .~ .owner
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            accountScopes: ["account@google.com": writableScope],
            defaultRepo: .init(customCalendarsStubbing: [tag])
        )
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        let expect = expectConfirm("계정·캘린더 모두 쓰기 가능")
        let permission = try await firstOutput(expect, for: usecase.eventWritePermission(
            accountId: "account@google.com", calendarId: "cal1"
        ))

        // then
        #expect(permission == .writable)
    }

    @Test func eventWritePermission_whenCalendarAccessRoleIsNil_readOnlyCalendar() async throws {
        // given — 마이그레이션 직후 캐시된 태그에 accessRole 이 없는 상태 (fail-closed 대상)
        let tag = GoogleCalendar.Tag(id: "cal1", name: "cal1")
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            accountScopes: ["account@google.com": writableScope],
            defaultRepo: .init(customCalendarsStubbing: [tag])
        )
        usecase.prepare()
        try await Task.sleep(for: .milliseconds(100))

        // when
        let expect = expectConfirm("accessRole nil → fail-closed 로 readOnlyCalendar")
        let permission = try await firstOutput(expect, for: usecase.eventWritePermission(
            accountId: "account@google.com", calendarId: "cal1"
        ))

        // then
        #expect(permission == .readOnlyCalendar)
    }
}


// MARK: - 역할 8: updateEvent() / removeEvent()

extension GoogleCalendarUsecaseImpleTests {

    private var dummyUpdatedEventOrigin: GoogleCalendar.EventOrigin {
        var origin = GoogleCalendar.EventOrigin(id: "event1", summary: "updated")
        origin.start = .init() |> \.dateTime .~ "2023-03-05T00:00:00+09:00"
        origin.end = .init() |> \.dateTime .~ "2023-03-06T00:00:00+09:00"
        return origin
    }

    @Test func updateEvent_callsRepositoryAndUpdatesSharedDataStore() async throws {
        // given
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(customUpdateEventOriginStubbing: dummyUpdatedEventOrigin)
        )
        var params = GoogleCalendar.EventEditParams()
        params.summary = "updated"

        // when
        let origin = try await usecase.updateEvent(
            "cal1", "event1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: params
        )

        // then
        #expect(origin.id == "event1")
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["event1"]?.name == "updated")
    }

    @Test func updateEvent_whenResponseIsSeriesMaster_doesNotCacheItAsTheDisplayedInstance() async throws {
        // given — "전체 일정" 저장은 구글이 시리즈 마스터(recurringEventId 없음 + recurrence 있음)를 돌려준다
        var seriesMaster = GoogleCalendar.EventOrigin(id: "series1", summary: "series updated")
        seriesMaster.recurrence = ["RRULE:FREQ=DAILY;COUNT=3"]
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(customUpdateEventOriginStubbing: seriesMaster)
        )

        // when
        let origin = try await usecase.updateEvent(
            "cal1", "series1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: .init()
        )

        // then — 응답은 그대로 반환하되, 시리즈 마스터를 인스턴스인 양 SharedDataStore 에 캐시하지 않는다
        #expect(origin.id == "series1")
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["series1"] == nil)
    }

    @Test func updateEvent_whenResponseIsSeriesMaster_refreshesInstancesOverCachedPeriod() async throws {
        // given — 이미 조회된 이벤트가 캐시에 있고, 그 span 이 인스턴스 재조회 구간이 된다
        var seriesMaster = GoogleCalendar.EventOrigin(id: "series1", summary: "series updated")
        seriesMaster.recurrence = ["RRULE:FREQ=DAILY;COUNT=3"]
        let repo = PrivateStubRepository(customUpdateEventOriginStubbing: seriesMaster)
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)
        let alreadyLoaded = GoogleCalendar.Event(
            "loaded", "cal1", accountId: "account@google.com",
            name: "loaded", colorId: nil, time: .period(100..<200)
        )
        // 시각을 바꾸면 인스턴스 id 가 달라져 응답에 없는 낡은 항목이 된다
        let staleInstance = GoogleCalendar.Event(
            "series1_old", "cal1", accountId: "account@google.com",
            name: "stale instance", colorId: nil, time: .period(100..<200)
        )
        stubStore.put(
            [String: GoogleCalendar.Event].self,
            key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["loaded": alreadyLoaded, "series1_old": staleInstance]
        )

        // when
        _ = try await usecase.updateEvent(
            "cal1", "series1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: .init()
        )
        try await Task.sleep(for: .milliseconds(100))

        // then — 캐시 span(100..<200)으로 그 시리즈의 인스턴스만 재조회하고 결과를 캐시에 병합한다
        #expect(repo.didLoadRepeatingInstancesWith?.eventId == "series1")
        #expect(repo.didLoadRepeatingInstancesWith?.calendarId == "cal1")
        #expect(repo.didLoadRepeatingInstancesWith?.period == 100..<200)
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["series1_0"]?.name == "refreshed instance")
        #expect(cached?["series1_1"]?.name == "refreshed instance")
        #expect(cached?["series1_old"] == nil)
        #expect(cached?["loaded"] != nil)
    }

    @Test func updateEvent_whenRecurrenceRemoved_refreshesCachedPeriod() async throws {
        // given — 반복 해제 응답은 마스터가 아니다(recurrence == nil) — 결과만 보면 재조회가 필요 없어 보인다
        let notMasterAnymore = GoogleCalendar.EventOrigin(id: "series1", summary: "no longer repeating")
        let repo = PrivateStubRepository(customUpdateEventOriginStubbing: notMasterAnymore)
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)
        stubStore.put(
            [String: GoogleCalendar.Event].self,
            key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["loaded": dummyEvent("loaded")]
        )
        var params = GoogleCalendar.EventEditParams()
        params.recurrence = []

        // when
        _ = try await usecase.updateEvent(
            "cal1", "series1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: params
        )
        try await Task.sleep(for: .milliseconds(100))

        // then — 대상이 반복 해제 대상이었으므로 펼쳐진 인스턴스를 걷어내는 재조회가 돈다
        #expect(repo.didLoadRepeatingInstancesWith?.eventId == "series1")
    }

    @Test func updateEvent_whenRecurrenceAdded_refreshesCachedPeriod() async throws {
        // given — 이번 응답 자체는 마스터가 아니지만(recurringEventId nil, recurrence nil), 대상에 반복을 새로 실었다
        let notMasterYet = GoogleCalendar.EventOrigin(id: "event1", summary: "now repeating")
        let repo = PrivateStubRepository(customUpdateEventOriginStubbing: notMasterYet)
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)
        stubStore.put(
            [String: GoogleCalendar.Event].self,
            key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["loaded": dummyEvent("loaded")]
        )
        var params = GoogleCalendar.EventEditParams()
        params.recurrence = ["RRULE:FREQ=DAILY;COUNT=3"]

        // when
        _ = try await usecase.updateEvent(
            "cal1", "event1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: params
        )
        try await Task.sleep(for: .milliseconds(100))

        // then
        #expect(repo.didLoadRepeatingInstancesWith?.eventId == "event1")
    }

    @Test func updateEvent_whenOnlyOtherFieldsChanged_cachesResponseOnly() async throws {
        // given — 반복과 무관한 필드만 바뀌었고 응답도 인스턴스다
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(customUpdateEventOriginStubbing: dummyUpdatedEventOrigin)
        )
        var params = GoogleCalendar.EventEditParams()
        params.summary = "updated"

        // when
        _ = try await usecase.updateEvent(
            "cal1", "event1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: params
        )

        // then — 재조회 없이 응답만 캐시에 반영
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["event1"]?.name == "updated")
    }

    @Test func removeEvent_removesFromSharedDataStore() async throws {
        // given
        let usecase = makeUsecase(
            accounts: ["account@google.com"],
            defaultRepo: .init(customUpdateEventOriginStubbing: dummyUpdatedEventOrigin)
        )
        _ = try await usecase.updateEvent(
            "cal1", "event1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: .init()
        )
        let seeded = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(seeded?["event1"] != nil)

        // when
        try await usecase.removeEvent(
            "cal1", "event1", accountId: "account@google.com", scope: .thisEventOnly
        )

        // then
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["event1"] == nil)
    }

    @Test func removeEvent_allEvents_removesExpandedInstancesOfSeries() async throws {
        // given — 캐시엔 마스터가 아니라 펼쳐진 인스턴스들이 들어 있다
        let usecase = makeUsecase(accounts: ["account@google.com"])
        let instances: [String: GoogleCalendar.Event] = [
            "event1_100": self.dummyEvent("event1_100"),
            "event1_200": self.dummyEvent("event1_200"),
            "other": self.dummyEvent("other")
        ]
        stubStore.put(
            [String: GoogleCalendar.Event].self,
            key: ShareDataKeys.googleCalendarEvents.rawValue, instances
        )

        // when
        try await usecase.removeEvent(
            "cal1", "event1", accountId: "account@google.com", scope: .allEvents
        )

        // then
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["event1_100"] == nil)
        #expect(cached?["event1_200"] == nil)
        #expect(cached?["other"] != nil)
    }

    @Test func updateEvent_whenRecurrenceAdded_removesStaleSingleEventFromCache() async throws {
        // given — 반복 없던 단일 이벤트가 eventId 키로 캐시돼 있다
        var seriesMaster = GoogleCalendar.EventOrigin(id: "event1", summary: "now repeating")
        seriesMaster.recurrence = ["RRULE:FREQ=DAILY;COUNT=3"]
        let repo = PrivateStubRepository(customUpdateEventOriginStubbing: seriesMaster)
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)
        stubStore.put(
            [String: GoogleCalendar.Event].self,
            key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["event1": self.dummyEvent("event1")]
        )
        var params = GoogleCalendar.EventEditParams()
        params.recurrence = ["RRULE:FREQ=DAILY;COUNT=3"]

        // when
        _ = try await usecase.updateEvent(
            "cal1", "event1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: params
        )
        try await Task.sleep(for: .milliseconds(100))

        // then — 옛 단일 이벤트 캐시가 eventId 키에 남지 않는다
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["event1"] == nil)
    }

    @Test func updateEvent_whenRecurrenceRemoved_cachesEventItself() async throws {
        // given — 반복 해제 응답은 마스터가 아니다(recurrence == nil) — 반복이 풀린 단일 이벤트다
        var notMasterAnymore = GoogleCalendar.EventOrigin(id: "series1", summary: "no longer repeating")
        notMasterAnymore.start = .init() |> \.dateTime .~ "2023-03-05T00:00:00+09:00"
        notMasterAnymore.end = .init() |> \.dateTime .~ "2023-03-06T00:00:00+09:00"
        let repo = PrivateStubRepository(customUpdateEventOriginStubbing: notMasterAnymore)
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)
        var params = GoogleCalendar.EventEditParams()
        params.recurrence = []

        // when
        _ = try await usecase.updateEvent(
            "cal1", "series1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: params
        )
        try await Task.sleep(for: .milliseconds(100))

        // then — 본체가 eventId 키에 갱신되어 반영된다
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["series1"]?.name == "no longer repeating")
    }

    @Test func updateEvent_whenRecurrenceRemoved_removesStaleInstancesFromCache() async throws {
        // given — 기존에 펼쳐진 반복 인스턴스들이 series1_* 로 캐시돼 있다
        var notMasterAnymore = GoogleCalendar.EventOrigin(id: "series1", summary: "no longer repeating")
        notMasterAnymore.start = .init() |> \.dateTime .~ "2023-03-05T00:00:00+09:00"
        notMasterAnymore.end = .init() |> \.dateTime .~ "2023-03-06T00:00:00+09:00"
        let repo = PrivateStubRepository(customUpdateEventOriginStubbing: notMasterAnymore)
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)
        stubStore.put(
            [String: GoogleCalendar.Event].self,
            key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["series1_0": self.dummyEvent("series1_0"), "series1_1": self.dummyEvent("series1_1")]
        )
        var params = GoogleCalendar.EventEditParams()
        params.recurrence = []

        // when
        _ = try await usecase.updateEvent(
            "cal1", "series1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, params: params
        )
        try await Task.sleep(for: .milliseconds(100))

        // then — 걷힌 series1_* 옛 인스턴스는 사라지고 본체만 남는다
        let cached = stubStore.value(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue
        )
        #expect(cached?["series1_0"] == nil)
        #expect(cached?["series1_1"] == nil)
        #expect(cached?["series1"]?.name == "no longer repeating")
    }

    private func dummyEvent(_ eventId: String) -> GoogleCalendar.Event {
        return GoogleCalendar.Event(
            eventId, "cal1", accountId: "account@google.com",
            name: eventId, colorId: nil, time: .period(0..<100)
        )
    }
}


// MARK: - 역할 9: respondToEvent()

extension GoogleCalendarUsecaseImpleTests {

    @Test func respondToEvent_delegatesToAccountRepository() async throws {
        // given
        let repo = PrivateStubRepository(
            customRespondOriginStubbing: GoogleCalendar.EventOrigin(id: "event1", summary: "responded")
        )
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)

        // when
        let origin = try await usecase.respondToEvent(
            "cal1", "event1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, responseStatus: .declined
        )

        // then
        #expect(repo.didRespondToEventWith?.calendarId == "cal1")
        #expect(repo.didRespondToEventWith?.timeZone == "Asia/Seoul")
        #expect(repo.didRespondToEventWith?.eventId == "event1")
        #expect(repo.didRespondToEventWith?.responseStatus == .declined)
        #expect(origin.summary == "responded")
    }

    @Test func respondToEvent_whenRepositoryFails_throws() async throws {
        // given
        let repo = PrivateStubRepository(respondToEventShouldFail: true)
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)

        // when & then
        await #expect(throws: (any Error).self) {
            _ = try await usecase.respondToEvent(
                "cal1", "event1", accountId: "account@google.com",
                at: TimeZone(identifier: "Asia/Seoul")!, responseStatus: .accepted
            )
        }
    }

    @Test func respondToEvent_doesNotRunUpdateEventFlow() async throws {
        // given
        let repo = PrivateStubRepository()
        let usecase = makeUsecase(accounts: ["account@google.com"], defaultRepo: repo)

        // when
        _ = try await usecase.respondToEvent(
            "cal1", "event1", accountId: "account@google.com",
            at: TimeZone(identifier: "Asia/Seoul")!, responseStatus: .accepted
        )

        // then — RSVP 는 updateEvent 와 그 인스턴스 재조회 로직을 타지 않는다
        #expect(repo.didUpdateEventWith == nil)
        #expect(repo.didLoadRepeatingInstancesWith == nil)
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
    func reauthenticateForWriteScope(
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


private final class PrivateStubRepository: GoogleCalendarRepository, @unchecked Sendable {

    private var stubColors: [GoogleCalendar.Colors]
    private var stubCalendarTags: [[GoogleCalendar.Tag]]
    var eventsMocking: PassthroughSubject<[GoogleCalendar.Event], any Error>?
    private let customUpdateEventOriginStubbing: GoogleCalendar.EventOrigin?
    private let customRespondOriginStubbing: GoogleCalendar.EventOrigin?
    private let respondToEventShouldFail: Bool
    var didUpdateEventWith: (eventId: String, params: GoogleCalendar.EventEditParams)?
    var didRespondToEventWith: (
        calendarId: String, timeZone: String, eventId: String,
        responseStatus: GoogleCalendar.AttendeeResponseStatus
    )?

    init(
        customCalendarsStubbing: [GoogleCalendar.Tag]? = nil,
        eventsMocking: PassthroughSubject<[GoogleCalendar.Event], any Error>? = nil,
        customUpdateEventOriginStubbing: GoogleCalendar.EventOrigin? = nil,
        customRespondOriginStubbing: GoogleCalendar.EventOrigin? = nil,
        respondToEventShouldFail: Bool = false
    ) {
        self.customUpdateEventOriginStubbing = customUpdateEventOriginStubbing
        self.customRespondOriginStubbing = customRespondOriginStubbing
        self.respondToEventShouldFail = respondToEventShouldFail
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

    var didLoadRepeatingInstancesWith: (calendarId: String, eventId: String, period: Range<TimeInterval>)?
    func loadRepeatingEventInstances(
        _ calendarId: String, _ eventId: String, in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        self.didLoadRepeatingInstancesWith = (calendarId, eventId, period)
        let instances = (0..<2).map { i -> GoogleCalendar.Event in
            .init(
                "\(eventId)_\(i)", calendarId,
                accountId: "stub@gmail.com",
                name: "refreshed instance", colorId: "color",
                time: .period(period.lowerBound..<period.lowerBound + TimeInterval(i + 1))
            )
        }
        return Just(instances).mapAsAnyError().eraseToAnyPublisher()
    }

    func updateEvent(
        _ calendarId: String, _ timeZone: String, _ eventId: String, _ params: GoogleCalendar.EventEditParams
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        self.didUpdateEventWith = (eventId, params)
        let origin = self.customUpdateEventOriginStubbing ?? GoogleCalendar.EventOrigin(id: eventId, summary: params.summary)
        return Just(origin).mapAsAnyError().eraseToAnyPublisher()
    }

    func respondToEvent(
        _ calendarId: String,
        _ timeZone: String,
        _ eventId: String,
        _ responseStatus: GoogleCalendar.AttendeeResponseStatus
    ) async throws -> GoogleCalendar.EventOrigin {
        self.didRespondToEventWith = (calendarId, timeZone, eventId, responseStatus)
        guard !self.respondToEventShouldFail else { throw TestError() }
        return self.customRespondOriginStubbing
            ?? GoogleCalendar.EventOrigin(id: eventId, summary: "some")
    }

    func removeEvent(_ calendarId: String, _ eventId: String) -> AnyPublisher<Void, any Error> {
        return Just(()).mapAsAnyError().eraseToAnyPublisher()
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
