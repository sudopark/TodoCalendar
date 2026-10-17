//
//  ExternalCalendarDBMigrationImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import SQLiteService

@testable import Repository


@Suite("ExternalCalendarDBMigrationImpleTests", .serialized)
final class ExternalCalendarDBMigrationImpleTests {

    private let dbNameSuffix: String = UUID().uuidString
    private var openedServices: [SQLiteService] = []

    // 두 버전을 다르게 줘야 서비스별로 자기 상수를 소비하는지 가려진다
    private let migration = ExternalCalendarDBMigrationImple(
        googleCalendarDBVersion: 1,
        appleCalendarDBVersion: 2
    )

    private struct StubMigrationFailure: Error { }

    private func dbPath(_ name: String) -> String {
        try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name)_\(dbNameSuffix).db")
            .path
    }

    // 커넥션을 닫은 뒤 파일을 지운다 — 열린 채로 unlink 하면 sqlite 가
    // "vnode unlinked while in use" 로 프로세스를 죽인다
    private func withMigrationDB(
        name: String,
        userVersion: Int32 = 0,
        seed: @escaping (any DataBase) throws -> Void = { _ in },
        body: (SQLiteService) async throws -> Void
    ) async throws {
        let path = self.dbPath(name)
        let service = SQLiteService()
        self.openedServices.append(service)

        let outcome: Result<Void, any Error>
        do {
            try await service.async.open(path: path)
            try await service.async.run { db in
                try seed(db)
                try db.updateUserVersion(userVersion)
            }
            try await body(service)
            outcome = .success(())
        } catch {
            outcome = .failure(error)
        }

        self.openedServices.forEach { _ = $0.close() }
        self.openedServices.removeAll()
        try? FileManager.default.removeItem(atPath: path)
        try outcome.get()
    }

    // 시드 커넥션은 풀이 열기 전에 닫고, 풀 커넥션은 파일을 지우기 전에 닫는다
    private func withPool(
        name: String,
        serviceId: String,
        seed: @escaping (any DataBase) throws -> Void = { _ in },
        onFirstOpen: @escaping @Sendable (String, SQLiteService) async throws -> Void,
        body: (ExternalCalendarSQLiteConnectionPoolImple) async throws -> Void
    ) async throws {
        let path = self.dbPath(name)
        let seedService = SQLiteService()
        var isSeedClosed = false
        let pool = ExternalCalendarSQLiteConnectionPoolImple(
            dbPathMap: [serviceId: path],
            onFirstOpen: onFirstOpen
        )

        let outcome: Result<Void, any Error>
        do {
            try await seedService.async.open(path: path)
            try await seedService.async.run { db in
                try seed(db)
                try db.updateUserVersion(0)
            }
            _ = seedService.close()
            isSeedClosed = true
            try await body(pool)
            outcome = .success(())
        } catch {
            outcome = .failure(error)
        }

        if !isSeedClosed { _ = seedService.close() }
        try? await pool.close(serviceId: serviceId)
        try? FileManager.default.removeItem(atPath: path)
        try outcome.get()
    }

    private var migrateOnFirstOpen: @Sendable (String, SQLiteService) async throws -> Void {
        return { [migration = self.migration] serviceId, service in
            try await migration.runMigration(serviceId: serviceId, dbService: service)
        }
    }

    private func requireSelectSucceeds(_ service: SQLiteService, _ statement: String) async throws {
        try await service.async.run { db in
            try db.execute(statement)
        }
    }

    private func loadUserVersion(_ service: SQLiteService) async throws -> Int32 {
        return try await service.async.run(Int32.self) { db in
            try db.userVersion()
        }
    }

    private func loadTags(_ service: SQLiteService) async throws -> [GoogleCalendarEventTagTable.Entity] {
        return try await service.async.run([GoogleCalendarEventTagTable.Entity].self) { db in
            try db.load(GoogleCalendarEventTagTable.self, query: GoogleCalendarEventTagTable.selectAll())
        }
    }

    private func seedV0Tag(_ db: any DataBase) throws {
        try db.createTableOrNot(GoogleCalendarEventTagTableV1.self)
        let entity = GoogleCalendarEventTagTableV1.Entity(
            accountId: "seed-account",
            tagId: "seed-tag",
            name: "seed-name",
            description: "seed-description",
            background: "seed-background",
            foreground: "seed-foreground",
            colorId: "seed-color",
            isSelected: true
        )
        try db.insert(GoogleCalendarEventTagTableV1.self, entities: [entity], shouldReplace: true)
    }

    private func seedCurrentTag(_ db: any DataBase) throws {
        try db.createTableOrNot(GoogleCalendarEventTagTable.self)
        let entity = GoogleCalendarEventTagTable.Entity(
            accountId: "seed-account",
            tagId: "seed-tag",
            name: "seed-name",
            description: "seed-description",
            background: "seed-background",
            foreground: "seed-foreground",
            colorId: "seed-color",
            isSelected: true,
            accessRole: "seed-role"
        )
        try db.insert(GoogleCalendarEventTagTable.self, entities: [entity], shouldReplace: true)
    }
}


// MARK: - 구글 DB

extension ExternalCalendarDBMigrationImpleTests {

    @Test func runMigration_googleDB_v0ToV1_addsAccessRoleAndKeepsRows() async throws {
        try await self.withMigrationDB(name: "external_migration_google", seed: self.seedV0Tag) { service in
            // given
            let serviceId = GoogleCalendarService.id

            // when
            try await self.migration.runMigration(serviceId: serviceId, dbService: service)

            // then
            try await self.requireSelectSucceeds(service, "SELECT access_role FROM google_calendar_list;")
            let tags = try await self.loadTags(service)
            #expect(tags.count == 1)
            #expect(tags.first?.accountId == "seed-account")
            #expect(tags.first?.tagId == "seed-tag")
            #expect(tags.first?.name == "seed-name")
            #expect(tags.first?.description == "seed-description")
            #expect(tags.first?.background == "seed-background")
            #expect(tags.first?.foreground == "seed-foreground")
            #expect(tags.first?.colorId == "seed-color")
            #expect(tags.first?.isSelected == true)
            #expect(tags.first?.accessRole == nil)
            #expect(try await self.loadUserVersion(service) == 1)
        }
    }

    @Test func runMigration_googleDB_whenAlreadyAtV1_keepsRows() async throws {
        try await self.withMigrationDB(
            name: "external_migration_google_current",
            userVersion: 1,
            seed: self.seedCurrentTag
        ) { service in
            // given
            let serviceId = GoogleCalendarService.id

            // when
            try await self.migration.runMigration(serviceId: serviceId, dbService: service)

            // then
            let tags = try await self.loadTags(service)
            #expect(tags.count == 1)
            #expect(tags.first?.tagId == "seed-tag")
            #expect(tags.first?.accessRole == "seed-role")
            #expect(try await self.loadUserVersion(service) == 1)
        }
    }
}


// MARK: - 애플 DB

extension ExternalCalendarDBMigrationImpleTests {

    @Test func runMigration_appleDB_doesNotRunGoogleStep() async throws {
        try await self.withMigrationDB(name: "external_migration_apple", seed: self.seedV0Tag) { service in
            // given
            let serviceId = AppleCalendarService.id

            // when
            try await self.migration.runMigration(serviceId: serviceId, dbService: service)

            // then
            await #expect(throws: (any Error).self) {
                try await self.requireSelectSucceeds(service, "SELECT access_role FROM google_calendar_list;")
            }
            #expect(try await self.loadUserVersion(service) == 2)
        }
    }
}


// MARK: - 풀이 DB 를 열 때

extension ExternalCalendarDBMigrationImpleTests {

    @Test func open_appleServiceThroughPool_doesNotRunGoogleStep() async throws {
        try await self.withPool(
            name: "external_migration_pool_apple",
            serviceId: AppleCalendarService.id,
            seed: self.seedV0Tag,
            onFirstOpen: self.migrateOnFirstOpen
        ) { pool in
            // given - 구글 태그 테이블이 v0 로 서 있는 애플 DB 파일
            let serviceId = AppleCalendarService.id

            // when
            try await pool.open(serviceId: serviceId)

            // then
            let service = try await pool.connection(serviceId: serviceId)
            await #expect(throws: (any Error).self) {
                try await self.requireSelectSucceeds(service, "SELECT access_role FROM google_calendar_list;")
            }
            let userVersion = try await self.loadUserVersion(service)
            #expect(userVersion == 2)
        }
    }

    @Test func open_whenMigrationFails_stillOpensConnection() async throws {
        try await self.withPool(
            name: "external_migration_pool_failing",
            serviceId: AppleCalendarService.id,
            onFirstOpen: { _, _ in throw StubMigrationFailure() }
        ) { pool in
            // given
            let serviceId = AppleCalendarService.id

            // when
            var openError: (any Error)?
            do {
                try await pool.open(serviceId: serviceId)
            } catch {
                openError = error
            }

            // then
            #expect(openError == nil)
            #expect(await pool.hasConnection(serviceId: serviceId) == true)
            let service = try? await pool.connection(serviceId: serviceId)
            #expect(service != nil)
        }
    }
}
