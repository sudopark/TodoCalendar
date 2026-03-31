//
//  AppleCalendarLocalAggregatedRepositoryImpleTests.swift
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


@Suite("AppleCalendarLocalAggregatedRepositoryImpleTests", .serialized)
final class AppleCalendarLocalAggregatedRepositoryImpleTests: PublisherWaitable, LocalTestable {

    var cancelBag: Set<AnyCancellable>! = []
    let sqliteService: SQLiteService = .init()

    private func dbPath(_ name: String) -> String {
        try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name).db")
            .path
    }

    private var appleDBPath: String { dbPath("aggregated_apple") }

    private func cleanup() {
        try? FileManager.default.removeItem(atPath: appleDBPath)
    }

    private func makePool() async throws -> ExternalCalendarSQLiteConnectionPoolImple {
        let pool = ExternalCalendarSQLiteConnectionPoolImple(dbPathMap: [AppleCalendarService.id: appleDBPath])
        try await pool.open(serviceId: AppleCalendarService.id)
        return pool
    }

    private func makeRepository(
        isPermissionGranted: Bool,
        pool: any ExternalCalendarDBConnectionPool
    ) -> AppleCalendarLocalAggregatedRepositoryImple {
        let checker = StubAppleCalendarPermissionChecker(isGranted: isPermissionGranted)
        return AppleCalendarLocalAggregatedRepositoryImple(
            connectionPool: pool,
            permissionChecker: checker
        )
    }

    private func localStorage(pool: any ExternalCalendarDBConnectionPool) -> AppleCalendarLocalStorageImple {
        AppleCalendarLocalStorageImple(connectionPool: pool)
    }
}


// MARK: - 권한 없는 경우

extension AppleCalendarLocalAggregatedRepositoryImpleTests {

    @Test func tags_whenPermissionDenied_returnsEmpty() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: AppleCalendarService.id) } }

        // given
        let storage = localStorage(pool: pool)
        let tags: [AppleCalendar.Tag] = [.init(id: "cal-1", name: "Calendar", colorHex: nil)]
        try await storage.saveCalendarTags(tags)
        let repo = makeRepository(isPermissionGranted: false, pool: pool)

        // when
        let loaded = try await repo.loadCalendarTags().values.first(where: { _ in true })

        // then
        #expect(loaded?.isEmpty == true)
    }

    @Test func events_whenPermissionDenied_returnsEmpty() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: AppleCalendarService.id) } }

        // given
        let period: Range<TimeInterval> = 0..<1000
        let storage = localStorage(pool: pool)
        let events: [AppleCalendar.Event] = [
            .init(eventId: "e-1", calendarId: "cal-1", name: "Event", eventTime: .period(0..<500))
        ]
        try await storage.saveEvents(events, in: period)
        let repo = makeRepository(isPermissionGranted: false, pool: pool)

        // when
        let loaded = try await repo.loadEvents(in: period).values.first(where: { _ in true })

        // then
        #expect(loaded?.isEmpty == true)
    }
}


// MARK: - 권한 있는 경우

extension AppleCalendarLocalAggregatedRepositoryImpleTests {

    @Test func tags_whenPermissionGranted_returnsCachedTags() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: AppleCalendarService.id) } }

        // given
        let storage = localStorage(pool: pool)
        let tags: [AppleCalendar.Tag] = [
            .init(id: "cal-1", name: "Work", colorHex: "FF0000"),
            .init(id: "cal-2", name: "Personal", colorHex: nil)
        ]
        try await storage.saveCalendarTags(tags)
        let repo = makeRepository(isPermissionGranted: true, pool: pool)

        // when
        let loaded = try await repo.loadCalendarTags().values.first(where: { _ in true })

        // then
        #expect(loaded?.count == 2)
    }

    @Test func events_whenPermissionGranted_returnsCachedEvents() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: AppleCalendarService.id) } }

        // given
        let period: Range<TimeInterval> = 0..<1000
        let storage = localStorage(pool: pool)
        let events: [AppleCalendar.Event] = [
            .init(eventId: "e-1", calendarId: "cal-1", name: "Meeting", eventTime: .period(100..<300)),
            .init(eventId: "e-2", calendarId: "cal-2", name: "Lunch", eventTime: .period(400..<600))
        ]
        try await storage.saveEvents(events, in: period)
        let repo = makeRepository(isPermissionGranted: true, pool: pool)

        // when
        let loaded = try await repo.loadEvents(in: period).values.first(where: { _ in true })

        // then
        #expect(loaded?.count == 2)
    }
}


// MARK: - Helpers

private final class StubAppleCalendarPermissionChecker: AppleCalendarPermissionChecker, @unchecked Sendable {
    private let isGranted: Bool
    init(isGranted: Bool) { self.isGranted = isGranted }
    func requestAccess() async throws -> Bool { isGranted }
    func checkAccessStatus() -> Bool { isGranted }
}
