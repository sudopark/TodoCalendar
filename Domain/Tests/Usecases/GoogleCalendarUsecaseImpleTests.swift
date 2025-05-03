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
    
    private let spyViewAppearanceStore: SpyGoogleCalendarViewAppearanceStore = .init()
    private let stubStore: SharedDataStore = .init()
    private let service = GoogleCalendarService(scopes: [.readOnly])
    private let stubEventTagUsecae = StubEventTagUsecase()
    
    var cancelBag: Set<AnyCancellable>! = []
    
    private func updateAccountIntegrated(_ hasAccount: Bool) {
        if hasAccount {
            let account = ExternalServiceAccountinfo(service.identifier, email: "email")
            self.stubStore.put(
                [String: ExternalServiceAccountinfo].self,
                key: ShareDataKeys.externalCalendarAccounts.rawValue,
                [service.identifier: account]
            )
        } else {
            self.stubStore.put(
                [String: ExternalServiceAccountinfo].self,
                key: ShareDataKeys.externalCalendarAccounts.rawValue,
                [:]
            )
        }
    }
    
    private func makeUsecase(
        hasAccount: Bool,
        customCalendarsStubbing: [GoogleCalendar.Tag]? = nil
    ) -> GoogleCalendarUsecaseImple {
        let repository = PrivateStubRepository(
            customCalendarsStubbing: customCalendarsStubbing
        )
        let tags = (0..<10).map { EventTagId.custom("id:\($0)") }
        tags.forEach { id in
            self.stubEventTagUsecae.toggleEventTagIsOnCalendar(id)
        }
        self.updateAccountIntegrated(hasAccount)
        return .init(
            googleService: GoogleCalendarService(scopes: [.readOnly]),
            repository: repository,
            eventTagUsecase: self.stubEventTagUsecae,
            appearanceStore: self.spyViewAppearanceStore,
            sharedDataStore: self.stubStore
        )
    }
}


extension GoogleCalendarUsecaseImpleTests {
    
    @Test func usecase_whenPrepareAndHasAccount_updateColorsAtAppearanceStore() async throws {
        // given
        let usecase = self.makeUsecase(hasAccount: true)
        
        // when + 소두
        try await confirmation("prepare시 구캘 연동되어있으면 color 조회해서 appearance store에 저장") { confirm in
            self.spyViewAppearanceStore.didUpdatecColors = { color in
                confirm()
            }
            usecase.prepare()
            
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    
    @Test func usecase_whenPrepareAndHasNoAccount_notUpdateColors() async throws {
        // given
        let usecase = self.makeUsecase(hasAccount: false)
        
        // when + then
        try await confirmation("prepare시 구캘 연동 안되어있으면 color 조회해서 안함", expectedCount: 0) { confirm in
            self.spyViewAppearanceStore.didUpdatecColors = { color in
                confirm()
            }
            usecase.prepare()
            
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    
    @Test func usecase_whenGoogleCalendarAccountIntegrationChanged_updateColor() async throws {
        // given
        let usecase = self.makeUsecase(hasAccount: true)
        
        // when
        let hasColors = try await confirmation("연동여부에 따라 컬러 정보 스토어에 업데이트", expectedCount: 3) { confirm in
            
            var sender: [Bool] = []
            self.spyViewAppearanceStore.didUpdatecColors = { color in
                sender.append(self.spyViewAppearanceStore.color != nil)
                confirm()
            }
            self.spyViewAppearanceStore.didClearColor = {
                sender.append(self.spyViewAppearanceStore.color != nil)
                confirm()
            }
            
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(10))
            
            self.updateAccountIntegrated(false)
            try await Task.sleep(for: .milliseconds(10))
            
            self.updateAccountIntegrated(true)
            try await Task.sleep(for: .milliseconds(10))
            
            return sender
        }
        
        // then
        #expect(hasColors == [true, false, true])
    }
}

extension GoogleCalendarUsecaseImpleTests {
    
    @Test func usecase_updateCalendarTag_byIntegrationStatusChanged() async throws {
        // given
        let expect = expectConfirm("연동 여부에 따라 구글 캘린더 태그정보 업데이트")
        expect.count = 4
        let usecase = self.makeUsecase(hasAccount: false)
        
        // when
        let tagLists = try await self.outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            
            self.updateAccountIntegrated(true)
            
            self.updateAccountIntegrated(false)
        }
        
        // then
        let idSets = tagLists.map { ts in ts.map { $0.tagId }}
        #expect(idSets == [
            [],
            [],
            [
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag1"),
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag2")
            ],
            [],
        ])
    }
    
    @Test func usecase_whenServiceDisconnected_clearOffTagIds() async throws {
        // given
        let expect = expectConfirm("서비스 연동이 해제된 경우, 저장된 offTagId에서 서비스에 해당하는 아이디 삭제")
        expect.count = 2
        let usecase = self.makeUsecase(hasAccount: true)
        self.stubEventTagUsecae.toggleEventTagIsOnCalendar(
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag1")
        )
        self.stubEventTagUsecae.toggleEventTagIsOnCalendar(
            .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag2")
        )
        
        // when
        let offIdLists = try await self.outputs(expect, for: stubEventTagUsecae.offEventTagIdsOnCalendar()) {
            usecase.prepare()
            
            
            self.updateAccountIntegrated(false)
        }
        
        // then
        let hasGoogleServiceIds = offIdLists.map { os in
            return os.contains(where: { $0.externalServiceId == "google" })
        }
        #expect(hasGoogleServiceIds == [true, false])
    }
    
    // 캘린더목록 조회시에 공휴일 정보 포함되어있으면 기본 off 처리
    @Test func usecase_whenRefreshCalendarListAndContainHoliday_offGoogleCalendarHoliday() async throws {
        // given
        let expect = expectConfirm("구글 캘린더 목록 조회시에 공휴일 캘린더가 있는 경우, 기본 off 처리")
        expect.count = 2
        let stub: [GoogleCalendar.Tag] = [
            .init(id: "real", name: "name"),
            .init(id: "$ko.kr.official#holiday@group.v.calendar.google.com", name: "hoiday")
        ]
        let usecase = self.makeUsecase(hasAccount: true, customCalendarsStubbing: stub)
        
        // when
        let offIds = try await self.outputs(expect, for: self.stubEventTagUsecae.offEventTagIdsOnCalendar()) {
            usecase.prepare()
        }
        
        // then
        let offIdsInExternals = offIds.map { os in os.filter { $0.externalServiceId == "google"} }
        #expect(offIdsInExternals == [
            [],
            [.externalCalendar(serviceId: "google", id: "$ko.kr.official#holiday@group.v.calendar.google.com")]
        ])
    }
    
    @Test func usecase_refreshGoogleCalendarEventTags() async throws {
        // given
        let expect = expectConfirm("구글 캘린더 이벤트 태그 목록 새로고침")
        expect.count = 3
        let usecase = self.makeUsecase(hasAccount: true)
        
        // when
        let tagLists = try await self.outputs(expect, for: usecase.calendarTags) {
            usecase.prepare()
            
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.refreshGoogleCalendarEventTags()
        }
        
        // then
        let nameLists = tagLists
            .map { ts in ts.map { $0.name } }
            .map { $0.sorted() }
        #expect(nameLists == [
            [],
            ["tag1", "tag2"],
            ["tag1-new", "tag2-new"]
        ])
    }
    
    @Test func usecaes_whenRefreshGoogleCalendarEventTags_refreshColors() async throws {
        // given
        let usecase = self.makeUsecase(hasAccount: true)
        
        // when
        let colors = try await confirmation(
            "구글 캘린더 입네트 태그 목록 새로고침시에 color도 다시 조회",
            expectedCount: 2
        ) { confirm in
            
            var colors: [GoogleCalendar.Colors?] = []
            self.spyViewAppearanceStore.didUpdatecColors = {
                colors.append($0)
                confirm()
            }
            
            usecase.prepare()
            
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.refreshGoogleCalendarEventTags()
                    
            return colors
        }
        // then
        let calendarColorNames = colors.map { $0?.calendars.values }.map { $0?.first?.backgroudHex }
        #expect(calendarColorNames == ["b0", "new-b0"])
    }
}

// MARK: - events

extension GoogleCalendarUsecaseImpleTests {
    
    private var dummyAllDayEvent: GoogleCalendar.EventOrigin {
        var rawValue = GoogleCalendar.EventOrigin(id: "id", summary: "summary")
        rawValue.start = .init()
            |> \.date .~ "2023-03-03"
            |> \.timeZone .~ "Asia/Seoul"
        rawValue.end = .init()
            |> \.date .~ "2023-04-03"
        return rawValue
    }
    
    private var dummyPeriodEvent: GoogleCalendar.EventOrigin {
        var rawValue = GoogleCalendar.EventOrigin(id: "id", summary: "summary")
        rawValue.start = .init()
            |> \.dateTime .~ "2023-03-05T00:00:00+09:00"
        rawValue.end = .init()
            |> \.dateTime .~ "2023-03-06T00:00:00+09:00"
        return rawValue
    }
    
    // eventRawValue -> event
    @Test func convertEventRawValue_whenTimeIsAllday_converToEvent() {
        // given
        let origin = self.dummyAllDayEvent
        
        // when
        let event = GoogleCalendar.Event(
            origin, "calendar_id", "Asia/Seoul"
        )
        
        // then
        #expect(event?.eventId == "id")
        #expect(event?.name == "summary")
        #expect(
            event?.eventTagId == .externalCalendar(serviceId: GoogleCalendarService.id, id: "calendar_id")
        )
        let lowBound = "2023-03-03".date(
            form: "yyyy-MM-dd", timeZoneAbbre: "KST"
        )
        let upperBound = "2023-04-03".date(
                form: "yyyy-MM-dd", timeZoneAbbre: "KST"
        )
        let kst = TimeZone(abbreviation: "KST")!
        #expect(event?.eventTime == .allDay(
            lowBound.timeIntervalSince1970..<upperBound.timeIntervalSince1970,
            secondsFromGMT: Double(kst.secondsFromGMT()))
        )
    }
    
    @Test func convertEventRawValue_whenTimeIsPeriod_converToEvent() {
        // given
        let origin = self.dummyPeriodEvent
        
        // when
        let event = GoogleCalendar.Event(
            origin, "calendar_id", "Asia/Seoul"
        )
        
        // then
        #expect(event?.eventId == "id")
        #expect(event?.name == "summary")
        #expect(
            event?.eventTagId == .externalCalendar(serviceId: GoogleCalendarService.id, id: "calendar_id")
        )
        let lowBound = "2023-03-05T00:00:00+09:00".date(
            form: "yyyy-MM-dd'T'HH:mm:ssz", timeZoneAbbre: "KST"
        )
        let upperBound = "2023-03-06T00:00:00+09:00".date(
                form: "yyyy-MM-dd'T'HH:mm:ssZ", timeZoneAbbre: "KST"
        )
        #expect(event?.eventTime == .period(
            lowBound.timeIntervalSince1970..<upperBound.timeIntervalSince1970
        ))
    }
}


// MARK: - events

extension GoogleCalendarUsecaseImpleTests {
    
    @Test func usecase_refreshEventsInRange() async throws {
        // given
        let expect = expectConfirm("주어진 기간에 해당하는 구글 이벤트 조회")
        expect.count = 3
        let usecase = self.makeUsecase(hasAccount: true)
        usecase.prepare()
        
        // when
        let eventSource = usecase.events(in: 0..<100)
        let eventLists = try await self.outputs(expect, for: eventSource) {
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.refreshEvents(in: 0..<100)
        }
        
        // then
        let eventCounts = eventLists.map { $0.count }
        #expect(eventCounts == [0, 10, 20])
        let calednar1Events = eventLists.last?.filter { $0.calendarId == "tag1" }
        #expect(calednar1Events?.count == 10)
        let calednar2Events = eventLists.last?.filter { $0.calendarId == "tag2" }
        #expect(calednar2Events?.count == 10)
    }
    
    @Test func usecase_whenAccountNotIntegrated_notRefreshEvents() async throws {
        // given
        let expect = expectConfirm("계정 연동 안되어있는경우 이벤트 조회 안함")
        expect.count = 0
        let usecase = self.makeUsecase(hasAccount: false)
        usecase.prepare()
        
        // when
        let eventSource = usecase.events(in: 0..<100).filter { !$0.isEmpty }
        let eventLists = try await self.outputs(expect, for: eventSource) {
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.refreshEvents(in: 0..<10)
        }
        
        // then
        #expect(eventLists.count == 0)
    }
    
    @Test func usecase_provideEvents_inRange() async throws {
        // given
        let expect = expectConfirm("주어진 기간에 해당하는 이벤트만 제공")
        expect.count = 3
        let usecase = self.makeUsecase(hasAccount: true)
        usecase.prepare()
        
        // when
        let eventSource = usecase.events(in: 3..<20)
        let eventLists = try await self.outputs(expect, for: eventSource) {
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.refreshEvents(in: 0..<10)
        }
        
        // then
        #expect(eventLists.count == 3)
        let last = eventLists.last
        let calendar1Events = last?.filter { $0.calendarId == "tag1" }
        #expect(
            calendar1Events?.map { $0.eventId }.sorted() == (3..<10).map { "event:\($0)-tag1" }
        )
        let calendar2Events = last?.filter { $0.calendarId == "tag2" }
        #expect(
            calendar2Events?.map { $0.eventId }.sorted() == (3..<10).map { "event:\($0)-tag2" }
        )
    }
    
    @Test func usecase_loadEventDetail() async throws {
        // given
        let expect = expectConfirm("구글 이벤트 디테일 조회")
        let usecase = self.makeUsecase(hasAccount: true)
        
        // when
        let loading = usecase.eventDetail("calendar1", "event", at: .current)
        let origin = try await self.firstOutput(expect, for: loading)
        
        // then
        #expect(origin != nil)
    }
    
    @Test func usecase_whenAfterDisconnectAccount_clearEvents() async throws {
        // given
        let expect = self.expectConfirm("계정 연동 해제된 경우, 저장된 이벤트 삭제")
        expect.count = 4
        expect.timeout = .milliseconds(1000)
        let usecase = self.makeUsecase(hasAccount: true)
        usecase.prepare()
        
        // when
        let eventSource = usecase.events(in: 0..<100)
        let eventLists = try await self.outputs(expect, for: eventSource) {
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.refreshEvents(in: 0..<100)
            
            try await Task.sleep(for: .milliseconds(100))
            self.updateAccountIntegrated(false)
        }
        
        // then
        let eventCounts = eventLists.map { $0.count }
        #expect(eventCounts == [0, 10, 20, 0])
    }
}

extension GoogleCalendarUsecaseImpleTests {
    
    @Test func usecase_provideIntegratedAccount() async throws {
        // given
        let expect = self.expectConfirm("연동된 계정정보 제공")
        expect.count = 3
        let usecase = self.makeUsecase(hasAccount: false)
        usecase.prepare()
        
        // when
        let accounts = try await self.outputs(expect, for: usecase.integratedAccount) {
            
            self.updateAccountIntegrated(true)
            
            self.updateAccountIntegrated(false)
        }
        
        // then
        let hasAccounts = accounts.map { $0 != nil }
        #expect(hasAccounts == [false, true, false])
    }
}

private final class PrivateStubRepository: GoogleCalendarRepository, @unchecked Sendable {
    
    private var stubColors: [GoogleCalendar.Colors] = []
    private var stubCalendarTags: [[GoogleCalendar.Tag]] = []
    
    init(
        customCalendarsStubbing: [GoogleCalendar.Tag]? = nil
    ) {
        self.stubColors = [
            .init(
                calendars: ["0": .init(foregroundHex: "f0", backgroudHex: "b0")],
                events: ["1": .init(foregroundHex: "f1", backgroudHex: "b1")]
            ),
            .init(
                calendars: ["0": .init(foregroundHex: "new-f0", backgroudHex: "new-b0")],
                events: ["1": .init(foregroundHex: "new-f1", backgroudHex: "new-b1")]
            )
        ]
        
        let defaultCalendar = [
            [
                GoogleCalendar.Tag(id: "tag1", name: "tag1"),
                GoogleCalendar.Tag(id: "tag2", name: "tag2"),
            ],
            [
                GoogleCalendar.Tag(id: "tag1", name: "tag1-new"),
                GoogleCalendar.Tag(id: "tag2", name: "tag2-new"),
            ]
        ]
        self.stubCalendarTags = customCalendarsStubbing.map { [$0] } ?? defaultCalendar
    }
    
    func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error> {
        guard !self.stubColors.isEmpty
        else {
            return Empty().eraseToAnyPublisher()
        }
        let first = stubColors.removeFirst()
        return Just(first)
            .mapAsAnyError()
            .eraseToAnyPublisher()
    }
    
    func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error> {
        guard !self.stubCalendarTags.isEmpty
        else {
            return Empty().eraseToAnyPublisher()
        }
        let first = self.stubCalendarTags.removeFirst()
        return Just(first)
            .mapAsAnyError()
            .eraseToAnyPublisher()
    }
    
    func loadEvents(
        _ calendarId: String, in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error> {
        let events = (0..<10).map { int -> GoogleCalendar.Event in
            return .init(
                "event:\(int)-\(calendarId)", calendarId,
                name: "some name",
                time: .period(period.lowerBound..<period.lowerBound+TimeInterval(int+1))
            )
        }
        return Just(events)
            .mapAsAnyError()
            .eraseToAnyPublisher()
    }
    
    func loadEventDetail(
        _ calendarId: String, _ timeZone: String, _ eventId: String
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        let origin = GoogleCalendar.EventOrigin(id: eventId, summary: "some")
        return Just(origin)
            .mapAsAnyError()
            .eraseToAnyPublisher()
    }
}

private final class SpyGoogleCalendarViewAppearanceStore: GoogleCalendarViewAppearanceStore, @unchecked Sendable {
    
     var color: GoogleCalendar.Colors?
    
    var didUpdatecColors: ((GoogleCalendar.Colors?) -> Void)?
    func apply(colors: GoogleCalendar.Colors) {
        self.color = colors
        self.didUpdatecColors?(colors)
    }
    
    var didClearColor: (() -> Void)?
    func clearGoogleCalendarColors() {
        self.color = nil
        self.didClearColor?()
    }
}
