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
import UnitTestHelpKit

@testable import Repository


@Suite("AppleCalendarLocalAggregatedRepositoryImpleTests", .serialized)
final class AppleCalendarLocalAggregatedRepositoryImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []

    private let dbNameSuffix: String = UUID().uuidString

    private func dbPath(_ name: String) -> String {
        try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name)_\(dbNameSuffix).db")
            .path
    }

    private var appleDBPath: String { dbPath("aggregated_apple") }

    // 커넥션을 닫은 뒤 파일을 지운다 — 열린 채로 unlink 하면 sqlite 가
    // "vnode unlinked while in use" 로 프로세스를 죽인다
    private func withOpenedPool(
        _ body: (ExternalCalendarSQLiteConnectionPoolImple) async throws -> Void
    ) async throws {
        let path = appleDBPath
        let pool = ExternalCalendarSQLiteConnectionPoolImple(dbPathMap: [AppleCalendarService.id: path])

        let outcome: Result<Void, any Error>
        do {
            try await pool.open(serviceId: AppleCalendarService.id)
            try await body(pool)
            outcome = .success(())
        } catch {
            outcome = .failure(error)
        }

        try? await pool.close(serviceId: AppleCalendarService.id)
        try? FileManager.default.removeItem(atPath: path)
        try outcome.get()
    }

    private func makeRepository(
        pool: any ExternalCalendarDBConnectionPool
    ) -> AppleCalendarLocalAggregatedRepositoryImple {
        return AppleCalendarLocalAggregatedRepositoryImple(connectionPool: pool)
    }

    private func localStorage(pool: any ExternalCalendarDBConnectionPool) -> AppleCalendarLocalStorageImple {
        AppleCalendarLocalStorageImple(connectionPool: pool)
    }
}


// MARK: - 캐시 조회

extension AppleCalendarLocalAggregatedRepositoryImpleTests {

    @Test func tags_returnsCachedTags() async throws {
        try await withOpenedPool { pool in
            // given
            let storage = localStorage(pool: pool)
            let tags: [AppleCalendar.Tag] = [
                .init(id: "cal-1", name: "Work", colorHex: "FF0000"),
                .init(id: "cal-2", name: "Personal", colorHex: nil)
            ]
            try await storage.saveCalendarTags(tags)
            let repo = makeRepository(pool: pool)

            // when
            let loaded = try await repo.loadCalendarTags().values.first(where: { _ in true })

            // then
            #expect(loaded?.count == 2)
        }
    }

    @Test func events_returnsCachedEvents() async throws {
        try await withOpenedPool { pool in
            // given
            let period: Range<TimeInterval> = 0..<1000
            let storage = localStorage(pool: pool)
            let origins: [AppleCalendar.EventOrigin] = [
                .init(eventId: "e-1", originalEventId: "e-1", calendarId: "cal-1", name: "Meeting", eventTime: .period(100..<300)),
                .init(eventId: "e-2", originalEventId: "e-2", calendarId: "cal-2", name: "Lunch", eventTime: .period(400..<600))
            ]
            try await storage.saveEventOrigins(origins, in: period)

            let repo = makeRepository(pool: pool)

            // when
            let loaded = try await repo.loadEvents(in: period).values.first(where: { _ in true })

            // then
            #expect(loaded?.count == 2)
        }
    }
}


