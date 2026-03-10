//
//  ExternalCalendarSQLiteConnectionPoolImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 3/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import SQLiteService
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("ExternalCalendarSQLiteConnectionPoolImpleTests", .serialized)
final class ExternalCalendarSQLiteConnectionPoolImpleTests {

    private let serviceId1 = "google"
    private let serviceId2 = "apple"

    private func testDBPath(name: String) -> String {
        (try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name).db"))
            .path
    }

    private func makePool() -> ExternalCalendarSQLiteConnectionPoolImple {
        return .init(dbPathMap: [
            serviceId1: testDBPath(name: "pool_service1"),
            serviceId2: testDBPath(name: "pool_service2")
        ])
    }

    private func cleanup() {
        try? FileManager.default.removeItem(atPath: testDBPath(name: "pool_service1"))
        try? FileManager.default.removeItem(atPath: testDBPath(name: "pool_service2"))
    }

    // 실제 SQLite 작업으로 연결 열림 여부 검증
    private func verifyDBIsOpen(_ service: SQLiteService) async throws {
        try await service.async.run { db in
            try db.createTableOrNot(GoogleCalendarColorsTable.self)
        }
    }
}


extension ExternalCalendarSQLiteConnectionPoolImpleTests {

    // open 이후 connection 획득 + 실제 DB 작업 성공
    @Test func open_and_connection_success() async throws {
        defer { cleanup() }
        let pool = makePool()

        try await pool.open(serviceId: serviceId1)
        let connection = try await pool.connection(serviceId: serviceId1)

        try await verifyDBIsOpen(connection)
        try await pool.close(serviceId: serviceId1)
    }

    // open → close → connection 접근 시 에러
    @Test func after_open_and_close_connection_throws() async throws {
        defer { cleanup() }
        let pool = makePool()

        try await pool.open(serviceId: serviceId1)
        try await pool.close(serviceId: serviceId1)

        await #expect(throws: (any Error).self) {
            _ = try await pool.connection(serviceId: serviceId1)
        }
    }

    // open 2회 → close 1회 → 연결 유지 (실제 DB 작업 성공)
    @Test func multiple_open_keeps_connection_until_matching_close_count() async throws {
        defer { cleanup() }
        let pool = makePool()

        try await pool.open(serviceId: serviceId1)
        try await pool.open(serviceId: serviceId1)
        try await pool.close(serviceId: serviceId1)

        let connection = try await pool.connection(serviceId: serviceId1)
        try await verifyDBIsOpen(connection)

        try await pool.close(serviceId: serviceId1)
    }

    // open 2회 → close 2회 → connection 접근 시 에러
    @Test func multiple_open_after_matching_close_connection_throws() async throws {
        defer { cleanup() }
        let pool = makePool()

        try await pool.open(serviceId: serviceId1)
        try await pool.open(serviceId: serviceId1)
        try await pool.close(serviceId: serviceId1)
        try await pool.close(serviceId: serviceId1)

        await #expect(throws: (any Error).self) {
            _ = try await pool.connection(serviceId: serviceId1)
        }
    }

    // serviceId 별 독립 관리: service1 close → service1 throws, service2 작동
    @Test func manages_connections_per_serviceId() async throws {
        defer { cleanup() }
        let pool = makePool()

        try await pool.open(serviceId: serviceId1)
        try await pool.open(serviceId: serviceId2)
        try await pool.close(serviceId: serviceId1)

        await #expect(throws: (any Error).self) {
            _ = try await pool.connection(serviceId: serviceId1)
        }
        let connection2 = try await pool.connection(serviceId: serviceId2)
        try await verifyDBIsOpen(connection2)

        try await pool.close(serviceId: serviceId2)
    }
}
