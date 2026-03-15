//
//  GoogleCalendarAggregatedRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 3/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("GoogleCalendarAggregatedRepositoryImpleTests", .serialized)
final class GoogleCalendarAggregatedRepositoryImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []

    private let googleServiceId = GoogleCalendarService.id
    private let account1 = "account1@google.com"
    private let account2 = "account2@google.com"

    private func dbPath(_ name: String) -> String {
        try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name).db")
            .path
    }

    private var googleDBPath: String { dbPath("aggregated_google") }

    private func cleanup() {
        try? FileManager.default.removeItem(atPath: googleDBPath)
    }

    private func makePool() async throws -> ExternalCalendarSQLiteConnectionPoolImple {
        let pool = ExternalCalendarSQLiteConnectionPoolImple(dbPathMap: [googleServiceId: googleDBPath])
        try await pool.open(serviceId: googleServiceId)
        return pool
    }

    private func makeRepository(
        accountEmails: [String],
        pool: any ExternalCalendarDBConnectionPool
    ) -> GoogleCalendarAggregatedRepositoryImple {
        let accountRepo = StubExternalCalendarIntegrateRepository(emails: accountEmails)
        return GoogleCalendarAggregatedRepositoryImple(
            connectionPool: pool,
            accountRepository: accountRepo
        )
    }

    private func localStorage(accountEmail: String, pool: any ExternalCalendarDBConnectionPool) -> GoogleCalendarLocalStorageImple {
        GoogleCalendarLocalStorageImple(connectionPool: pool, accountId: accountEmail)
    }
}


// MARK: - 연동 계정 없음

extension GoogleCalendarAggregatedRepositoryImpleTests {

    @Test func loadColors_whenNoAccount_returnsEmpty() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }
        let repo = makeRepository(accountEmails: [], pool: pool)

        let colors = try await repo.loadColors().values.first(where: { _ in true })

        #expect(colors?.calendars.isEmpty == true)
        #expect(colors?.events.isEmpty == true)
    }

    @Test func loadCalendarTags_whenNoAccount_returnsEmpty() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }
        let repo = makeRepository(accountEmails: [], pool: pool)

        let tags = try await repo.loadCalendarTags().values.first(where: { _ in true })

        #expect(tags?.isEmpty == true)
    }

    @Test func loadEvents_whenNoAccount_returnsEmpty() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }
        let repo = makeRepository(accountEmails: [], pool: pool)

        let events = try await repo.loadEvents("cal1", in: 0..<100).values.first(where: { _ in true })

        #expect(events?.isEmpty == true)
    }

    @Test func loadEventDetail_whenNoAccount_throws() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }
        let repo = makeRepository(accountEmails: [], pool: pool)

        var didThrow = false
        do {
            _ = try await repo.loadEventDetail("cal1", "Asia/Seoul", "event1").values.first(where: { _ in true })
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }
}


// MARK: - 단일 계정

extension GoogleCalendarAggregatedRepositoryImpleTests {

    @Test func loadColors_withSingleAccount_returnsAccountColors() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(accountEmail: account1, pool: pool)
        let colors = GoogleCalendar.Colors(
            calendars: ["c1": .init(foregroundHex: "f1", backgroudHex: "b1")],
            events: ["e1": .init(foregroundHex: "f2", backgroudHex: "b2")]
        )
        try await storage.updateColors(colors)

        let repo = makeRepository(accountEmails: [account1], pool: pool)
        let loaded = try await repo.loadColors().values.first(where: { _ in true })

        #expect(loaded?.calendars["c1"]?.backgroudHex == "b1")
        #expect(loaded?.events["e1"]?.backgroudHex == "b2")
    }

    @Test func loadCalendarTags_withSingleAccount_returnsTags() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(accountEmail: account1, pool: pool)
        try await storage.updateCalendarList([
            .init(id: "tag1", name: "Tag 1"),
            .init(id: "tag2", name: "Tag 2")
        ])

        let repo = makeRepository(accountEmails: [account1], pool: pool)
        let tags = try await repo.loadCalendarTags().values.first(where: { _ in true })

        #expect(tags?.map(\.id).sorted() == ["tag1", "tag2"])
    }

    @Test func loadEventDetail_withSingleAccount_returnsDetail() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(accountEmail: account1, pool: pool)
        let origin = GoogleCalendar.EventOrigin(id: "event1", summary: "Some Event")
        try await storage.updateEventDetail("cal1", "Asia/Seoul", origin)

        let repo = makeRepository(accountEmails: [account1], pool: pool)
        let detail = try await repo.loadEventDetail("cal1", "Asia/Seoul", "event1").values.first(where: { _ in true })

        #expect(detail?.id == "event1")
    }
}


// MARK: - 복수 계정 집계

extension GoogleCalendarAggregatedRepositoryImpleTests {

    @Test func loadColors_withMultipleAccounts_mergesColors() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        try await localStorage(accountEmail: account1, pool: pool).updateColors(.init(
            calendars: ["c1": .init(foregroundHex: "f1", backgroudHex: "b1")],
            events: [:]
        ))
        try await localStorage(accountEmail: account2, pool: pool).updateColors(.init(
            calendars: ["c2": .init(foregroundHex: "f2", backgroudHex: "b2")],
            events: ["e1": .init(foregroundHex: "f3", backgroudHex: "b3")]
        ))

        let repo = makeRepository(accountEmails: [account1, account2], pool: pool)
        let colors = try await repo.loadColors().values.first(where: { _ in true })

        #expect(colors?.calendars.keys.sorted() == ["c1", "c2"])
        #expect(colors?.events.keys.sorted() == ["e1"])
    }

    @Test func loadCalendarTags_withMultipleAccounts_mergesTags() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        try await localStorage(accountEmail: account1, pool: pool).updateCalendarList([
            .init(id: "tag1", name: "Tag 1")
        ])
        try await localStorage(accountEmail: account2, pool: pool).updateCalendarList([
            .init(id: "tag2", name: "Tag 2"),
            .init(id: "tag3", name: "Tag 3")
        ])

        let repo = makeRepository(accountEmails: [account1, account2], pool: pool)
        let tags = try await repo.loadCalendarTags().values.first(where: { _ in true })

        #expect(tags?.map(\.id).sorted() == ["tag1", "tag2", "tag3"])
    }

    @Test func loadEventDetail_withMultipleAccounts_findsAcrossAccounts() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        // account2에만 event2 저장
        let origin = GoogleCalendar.EventOrigin(id: "event2", summary: "Event in account2")
        try await localStorage(accountEmail: account2, pool: pool).updateEventDetail("cal1", "Asia/Seoul", origin)

        let repo = makeRepository(accountEmails: [account1, account2], pool: pool)
        let detail = try await repo.loadEventDetail("cal1", "Asia/Seoul", "event2").values.first(where: { _ in true })

        #expect(detail?.id == "event2")
    }
}


// MARK: - Test Doubles

private final class StubExternalCalendarIntegrateRepository: ExternalCalendarIntegrateRepository, @unchecked Sendable {

    private let emails: [String]

    init(emails: [String]) {
        self.emails = emails
    }

    func loadIntegratedAccounts() async throws -> [ExternalServiceAccountinfo] {
        return emails.map { ExternalServiceAccountinfo(GoogleCalendarService.id, email: $0) }
    }

    func save(_ credential: any OAuth2Credential, for service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo {
        throw RuntimeError("not supported")
    }

    func removeAccount(for serviceIdentifier: String) async throws { }
}
