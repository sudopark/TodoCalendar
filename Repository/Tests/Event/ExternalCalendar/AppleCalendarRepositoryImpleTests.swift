//
//  AppleCalendarRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import Extensions
import SQLiteService
import UnitTestHelpKit

@testable import Repository


@Suite("AppleCalendarRepositoryImpleTests", .serialized)
final class AppleCalendarRepositoryImpleTests: PublisherWaitable, LocalTestable {

    var cancelBag: Set<AnyCancellable>! = []
    let sqliteService: SQLiteService = .init()

    private let stubAccessor = StubAppleCalendarStoreAccessor()

    private func makeRepository() -> AppleCalendarRepositoryImple {
        let pool = StubConnectionPool(sqliteService)
        let storage = AppleCalendarLocalStorageImple(connectionPool: pool)
        return AppleCalendarRepositoryImple(
            storeAccessor: stubAccessor,
            cacheStorage: storage
        )
    }
}


// MARK: - loadCalendarTags — 캐시 우선, EventKit refresh

extension AppleCalendarRepositoryImpleTests {

    @Test func loadTags_emitsCachedThenRefreshed() async throws {
        try await runTestWithOpenClose("apple_repo_tags_1") { [self] in
            // given
            let expect = self.expectConfirm("캐시 → refresh 순으로 2번 방출")
            expect.count = 2
            let pool = StubConnectionPool(self.sqliteService)
            let storage = AppleCalendarLocalStorageImple(connectionPool: pool)
            let cachedTags: [AppleCalendar.Tag] = [.init(id: "cached-1", name: "Cached", colorHex: nil)]
            try await storage.saveCalendarTags(cachedTags)

            let repo = AppleCalendarRepositoryImple(
                storeAccessor: self.stubAccessor,
                cacheStorage: storage
            )

            // when
            let results = try await self.outputs(expect, for: repo.loadCalendarTags())

            // then — 캐시 먼저 emit, 이후 EventKit refresh emit
            #expect(results.count == 2)
            #expect(results.first?.map(\.id).contains("cached-1") == true)
            #expect(results.last?.map(\.id).contains("store-cal-0") == true)
        }
    }

    @Test func loadTags_whenNoCached_emitsOnlyRefreshed() async throws {
        try await runTestWithOpenClose("apple_repo_tags_2") { [self] in
            // given
            let expect = self.expectConfirm("캐시 없으면 refresh만 방출")
            let repo = self.makeRepository()

            // when
            let results = try await self.outputs(expect, for: repo.loadCalendarTags())

            // then
            #expect(results.count == 1)
            #expect(results.first?.isEmpty == false)
        }
    }

    @Test func loadTags_afterLoad_cacheIsUpdated() async throws {
        try await runTestWithOpenClose("apple_repo_tags_3") { [self] in
            // given
            let expect = self.expectConfirm("로드 후 캐시 업데이트")
            let pool = StubConnectionPool(self.sqliteService)
            let storage = AppleCalendarLocalStorageImple(connectionPool: pool)
            let repo = AppleCalendarRepositoryImple(
                storeAccessor: self.stubAccessor,
                cacheStorage: storage
            )

            // when
            let cacheBefore = try await storage.loadCalendarTags()
            let _ = try await self.outputs(expect, for: repo.loadCalendarTags())
            let cacheAfter = try await storage.loadCalendarTags()

            // then
            #expect(cacheBefore.isEmpty)
            #expect(cacheAfter.isEmpty == false)
        }
    }
}


// MARK: - loadEvents — 캐시 우선, EventKit refresh

extension AppleCalendarRepositoryImpleTests {

    @Test func loadEvents_emitsCachedThenRefreshed() async throws {
        try await runTestWithOpenClose("apple_repo_events_1") { [self] in
            // given
            let period: Range<TimeInterval> = 0..<1000
            let pool = StubConnectionPool(self.sqliteService)
            let storage = AppleCalendarLocalStorageImple(connectionPool: pool)
            let cachedEvent = AppleCalendar.Event(
                eventId: "cached-event",
                originalEventId: "cached-event",
                calendarId: "cal-1",
                name: "Cached",
                eventTime: .period(100..<500)
            )
            try await storage.saveEvents([cachedEvent], in: period)
            let repo = AppleCalendarRepositoryImple(
                storeAccessor: self.stubAccessor,
                cacheStorage: storage
            )

            // when
            let expect = self.expectConfirm("캐시 → refresh 순으로 방출")
            expect.count = 2
            let results = try await self.outputs(expect, for: repo.loadEvents(in: period))

            // then
            #expect(results.count == 2)
            #expect(results.first?.map(\.eventId).contains("cached-event") == true)
            #expect(results.last?.map(\.eventId).contains("store-event-0") == true)
        }
    }
}


// MARK: - AppleCalendarPermissionCheckerImple

extension AppleCalendarRepositoryImpleTests {

    @Test func checkAuthorizationStatus_reflectsStubValue() async throws {
        // given
        stubAccessor.isAuthorized = false
        let checker = AppleCalendarPermissionCheckerImple(storeAccessor: stubAccessor)

        // when
        let result = checker.checkAuthorizationStatus()

        // then
        #expect(result == .denied)
    }

    @Test func requestAccess_returnsStubValue() async throws {
        // given
        stubAccessor.requestGranted = true
        let checker = AppleCalendarPermissionCheckerImple(storeAccessor: stubAccessor)

        // when
        let result = try await checker.requestAccess()

        // then
        #expect(result == true)
    }
}


// MARK: - resetCache

extension AppleCalendarRepositoryImpleTests {

    @Test func resetCache_clearsAllData() async throws {
        try await runTestWithOpenClose("apple_repo_reset_1") { [self] in
            // given
            let period: Range<TimeInterval> = 0..<1000
            let pool = StubConnectionPool(self.sqliteService)
            let storage = AppleCalendarLocalStorageImple(connectionPool: pool)
            let event = AppleCalendar.Event(
                eventId: "e-1",
                originalEventId: "e-1",
                calendarId: "cal-1",
                name: "Event",
                eventTime: .period(0..<500)
            )
            try await storage.saveCalendarTags([.init(id: "cal-1", name: "Cal", colorHex: nil)])
            try await storage.saveEvents([event], in: period)
            let repo = AppleCalendarRepositoryImple(
                storeAccessor: self.stubAccessor,
                cacheStorage: storage
            )

            // when
            try await repo.resetCache()
            let tags = try await storage.loadCalendarTags()
            let events = try await storage.loadEvents(in: period)

            // then
            #expect(tags.isEmpty)
            #expect(events.isEmpty)
        }
    }
}


// MARK: - Helpers

private final class StubAppleCalendarStoreAccessor: AppleCalendarStoreAccessor, @unchecked Sendable {
    var isAuthorized: Bool = true
    var requestGranted: Bool = true
    var stubTags: [AppleCalendar.Tag] = (0..<3).map {
        .init(id: "store-cal-\($0)", name: "Store Calendar \($0)", colorHex: nil)
    }
    var stubOrigins: [AppleCalendar.EventOrigin] = (0..<2).map {
        AppleCalendar.EventOrigin(
            eventId: "store-event-\($0)", originalEventId: "store-event-\($0)",
            calendarId: "store-cal-0", name: "Store Event \($0)", eventTime: .period(100..<500)
        )
    }

    func requestFullAccessToEvents() async throws -> Bool { requestGranted }
    func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus { isAuthorized ? .fullAccess : .denied }
    func loadCalendarTags() -> [AppleCalendar.Tag] { stubTags }
    func loadEvents(in period: Range<TimeInterval>) -> [AppleCalendar.Event] {
        stubOrigins.map { $0.asEvent() }
    }
    func loadEventOrigin(id: String) -> AppleCalendar.EventOrigin? {
        stubOrigins.first { $0.eventId == id }
    }
}

private final class StubConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {
    private let service: SQLiteService
    init(_ service: SQLiteService) { self.service = service }
    func hasConnection(serviceId: String) async -> Bool { true }
    func connection(serviceId: String) async throws -> SQLiteService { service }
}
