//
//  AppDataMigrationImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 3/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Extensions
import SQLiteService

@testable import Repository


@Suite("AppDataMigrationImpleTests", .serialized)
final class AppDataMigrationImpleTests {

    private let accountId = "test@google.com"
    private let googleServiceId = GoogleCalendarService.id

    private func dbPath(_ name: String) -> String {
        try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name).db")
            .path
    }

    private var mainDBPath: String { dbPath("migration_main") }
    private var googleDBPath: String { dbPath("migration_google") }

    private func cleanup() {
        try? FileManager.default.removeItem(atPath: mainDBPath)
        try? FileManager.default.removeItem(atPath: googleDBPath)
    }

    private func openMainDB() async throws -> SQLiteService {
        let service = SQLiteService()
        try await service.async.open(path: mainDBPath)
        return service
    }

    private func makePool() async throws -> ExternalCalendarSQLiteConnectionPoolImple {
        let pool = ExternalCalendarSQLiteConnectionPoolImple(dbPathMap: [
            googleServiceId: googleDBPath
        ])
        try await pool.open(serviceId: googleServiceId)
        return pool
    }

    private func makeMigration(
        mainDB: SQLiteService,
        pool: any ExternalCalendarDBConnectionPool,
        flagStorage: FakeEnvironmentStorage = .init()
    ) -> AppDataMigrationImple {
        return .init(
            mainDB: mainDB,
            googleCalendarDBPool: pool,
            migrationFlagStorage: flagStorage,
            dbVersion: 6
        )
    }

    private func insertOldColors(_ mainDB: SQLiteService) async throws {
        try await mainDB.async.run { db in
            try db.createTableOrNot(OldGoogleCalendarColorsTable.self)
            let entities: [OldGoogleCalendarColorsTable.Entity] = [
                .init(calendar: "1", .init(foregroundHex: "#ffffff", backgroudHex: "#111111")),
                .init(event: "2", .init(foregroundHex: "#ffffff", backgroudHex: "#222222"))
            ]
            try db.insert(OldGoogleCalendarColorsTable.self, entities: entities)
        }
    }

    private func insertOldTags(_ mainDB: SQLiteService, tagId: String = "cal1") async throws {
        try await mainDB.async.run { db in
            try db.createTableOrNot(OldGoogleCalendarEventTagTable.self)
            var tag = GoogleCalendar.Tag(id: tagId, name: "Calendar \(tagId)")
            tag.backgroundColorHex = "#aaaaaa"
            try db.insert(OldGoogleCalendarEventTagTable.self, entities: [tag])
        }
    }

    private func insertOldEventOrigins(_ mainDB: SQLiteService) async throws -> [String] {
        let eventIds = ["event1", "event2"]
        try await mainDB.async.run { db in
            try db.createTableOrNot(OldGoogleCalendarEventOriginTable.self)
            try db.createTableOrNot(EventTimeTable.self)
            let origins: [OldGoogleCalendarEventOriginTable.Entity] = eventIds.map {
                .init("cal1", "Asia/Seoul", GoogleCalendar.EventOrigin(id: $0, summary: "Event \($0)"))
            }
            try db.insert(OldGoogleCalendarEventOriginTable.self, entities: origins)
            let times: [EventTimeTable.Entity] = eventIds.map {
                EventTimeTable.Entity($0, .at(0), nil)
            }
            try db.insert(EventTimeTable.self, entities: times)
        }
        return eventIds
    }

    private func loadGoogleDBColors(_ pool: ExternalCalendarSQLiteConnectionPoolImple) async throws -> [GoogleCalendarColorsTable.Entity] {
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        return try await googleDB.async.run { db in
            try? db.createTableOrNot(GoogleCalendarColorsTable.self)
            return (try? db.load(GoogleCalendarColorsTable.self, query: GoogleCalendarColorsTable.selectAll())) ?? []
        }
    }

    private func loadGoogleDBTags(_ pool: ExternalCalendarSQLiteConnectionPoolImple) async throws -> [GoogleCalendarEventTagTable.Entity] {
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        return try await googleDB.async.run { db in
            try? db.createTableOrNot(GoogleCalendarEventTagTable.self)
            return (try? db.load(GoogleCalendarEventTagTable.self, query: GoogleCalendarEventTagTable.selectAll())) ?? []
        }
    }

    private func loadGoogleDBOrigins(_ pool: ExternalCalendarSQLiteConnectionPoolImple) async throws -> [GoogleCalendarEventOriginTable.Entity] {
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        return try await googleDB.async.run { db in
            try? db.createTableOrNot(GoogleCalendarEventOriginTable.self)
            return (try? db.load(GoogleCalendarEventOriginTable.self, query: GoogleCalendarEventOriginTable.selectAll())) ?? []
        }
    }

    private func loadMainDBEventTimes(_ mainDB: SQLiteService) async throws -> [EventTimeTable.Entity] {
        return try await mainDB.async.run { db in
            try? db.createTableOrNot(EventTimeTable.self)
            return (try? db.load(EventTimeTable.self, query: EventTimeTable.selectAll())) ?? []
        }
    }
}


// MARK: - 마이그레이션 정상 수행

extension AppDataMigrationImpleTests {

    // mainDB의 구 데이터(colors, tags, origins, eventTimes)가 google_calendar.db로 이동
    @Test func migration_movesAllDataToGoogleDB() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        let times: [EventTimeTable.Entity] = try await googleDB.async.run { db in
            try? db.createTableOrNot(EventTimeTable.self)
            return (try? db.load(EventTimeTable.self, query: EventTimeTable.selectAll())) ?? []
        }

        #expect(colors.count == 2)
        #expect(colors.allSatisfy { $0.accountId == accountId })
        #expect(tags.count == 1)
        #expect(tags.allSatisfy { $0.accountId == accountId })
        #expect(origins.count == 2)
        #expect(origins.allSatisfy { $0.accountId == accountId })
        #expect(times.count == 2)
    }

    // google_calendar.db 쓰기에 실패하더라도 완료되어야 함
    @Test func migration_whenWriteFails_completesWithoutThrowing() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        let failingPool = FailingExternalCalendarSQLiteConnectionPool()
        let migration = makeMigration(mainDB: mainDB, pool: failingPool)

        await migration.migrateGoogleCalendarDataIfNeeded(accountId: accountId)
    }

    // 마이그레이션 이후 mainDB의 구 테이블 및 이벤트 타임 레코드 삭제
    @Test func migration_cleansUpOldDataAfterCompletion() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let remainingTimes = try await loadMainDBEventTimes(mainDB)
        #expect(remainingTimes.isEmpty)
    }

    // 한 번 마이그레이션 완료 이후 중복 실행하더라도 이미 이동한 데이터에 영향 없음
    @Test func migration_doesNotRunAgainAfterCompletion() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let flagStorage = FakeEnvironmentStorage()
        let migration = makeMigration(mainDB: mainDB, pool: pool, flagStorage: flagStorage)

        // 첫 번째 마이그레이션: tag "cal1" 이동
        try await insertOldTags(mainDB, tagId: "cal1")
        await migration.migrateGoogleCalendarDataIfNeeded(accountId: accountId)
        let tagsAfterFirst = try await loadGoogleDBTags(pool)

        // 두 번째 실행 전에 mainDB에 새 데이터 추가
        try await insertOldTags(mainDB, tagId: "cal2")
        await migration.migrateGoogleCalendarDataIfNeeded(accountId: accountId)
        let tagsAfterSecond = try await loadGoogleDBTags(pool)

        // 두 번째 실행은 스킵되어야 하므로 카운트가 늘지 않아야 함
        #expect(tagsAfterFirst.count == 1)
        #expect(tagsAfterSecond.count == tagsAfterFirst.count)
    }
}


// MARK: - 마이그레이션 실패

extension AppDataMigrationImpleTests {

    // mainDB read 실패 시 완료 처리 → 이후 호출에서 스킵됨
    @Test func migration_whenReadFails_marksCompletedAndSkipsNextTime() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let flagStorage = FakeEnvironmentStorage()

        // DB를 열지 않은 상태 → read 실패 → 완료로 처리
        let closedMainDB = SQLiteService()
        await makeMigration(mainDB: closedMainDB, pool: pool, flagStorage: flagStorage)
            .migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        // 두 번째 호출: valid mainDB에 데이터가 있어도 스킵되어야 함
        let validMainDB = try await openMainDB()
        defer { Task { try? await validMainDB.async.close() } }
        try await insertOldTags(validMainDB)

        await makeMigration(mainDB: validMainDB, pool: pool, flagStorage: flagStorage)
            .migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let tags = try await loadGoogleDBTags(pool)
        #expect(tags.isEmpty)
    }
}


// MARK: - 마이그레이션할 데이터 없는 엣지 케이스

extension AppDataMigrationImpleTests {

    // 구 DB에 데이터가 하나도 없어도 정상 완료
    @Test func migration_whenNoData_completesSuccessfully() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)
        // throw 없이 완료되면 성공
    }

    // 컬러만 없는 경우 — 태그, 이벤트는 정상 이동
    @Test func migration_whenNoColors_migratesTagsAndEvents() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)

        #expect(colors.isEmpty)
        #expect(tags.count == 1)
        #expect(origins.count == 2)
    }

    // 태그만 없는 경우 — 컬러, 이벤트는 정상 이동
    @Test func migration_whenNoTags_migratesColorsAndEvents() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        try await insertOldColors(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)

        #expect(colors.count == 2)
        #expect(tags.isEmpty)
        #expect(origins.count == 2)
    }

    // 이벤트만 없는 경우 — 컬러, 태그는 정상 이동
    @Test func migration_whenNoEvents_migratesColorsAndTags() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        defer { Task { try? await mainDB.async.close() } }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)

        #expect(colors.count == 2)
        #expect(tags.count == 1)
        #expect(origins.isEmpty)
    }
}


// MARK: - Test Doubles

private final class FailingExternalCalendarSQLiteConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {
    func connection(serviceId: String) async throws -> SQLiteService {
        throw RuntimeError("no connection available")
    }
}
