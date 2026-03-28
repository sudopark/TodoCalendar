//
//  GoogleCalendarLocalAggregatedRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 3/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("GoogleCalendarLocalAggregatedRepositoryImpleTests", .serialized)
final class GoogleCalendarLocalAggregatedRepositoryImpleTests: PublisherWaitable {

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
    ) -> GoogleCalendarLocalAggregatedRepositoryImple {
        let accountRepo = StubExternalCalendarIntegrateRepository(emails: accountEmails)
        return GoogleCalendarLocalAggregatedRepositoryImple(
            connectionPool: pool,
            accountRepository: accountRepo
        )
    }

    private func localStorage(pool: any ExternalCalendarDBConnectionPool) -> GoogleCalendarLocalStorageImple {
        GoogleCalendarLocalStorageImple(connectionPool: pool)
    }
}


// MARK: - 연동 계정 없음

extension GoogleCalendarLocalAggregatedRepositoryImpleTests {

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

extension GoogleCalendarLocalAggregatedRepositoryImpleTests {

    @Test func loadColors_withSingleAccount_returnsAccountColors() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(pool: pool)
        let colors = GoogleCalendar.Colors(
            ownerId: account1,
            calendars: ["c1": .init(foregroundHex: "f1", backgroudHex: "b1")],
            events: ["e1": .init(foregroundHex: "f2", backgroudHex: "b2")]
        )
        try await storage.updateColors(colors, accountId: account1)

        let repo = makeRepository(accountEmails: [account1], pool: pool)
        let loaded = try await repo.loadColors().values.first(where: { _ in true })

        #expect(loaded?.calendars["c1"]?.backgroudHex == "b1")
        #expect(loaded?.events["e1"]?.backgroudHex == "b2")
    }

    @Test func loadCalendarTags_withSingleAccount_returnsTags() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(pool: pool)
        try await storage.updateCalendarList([
            .init(id: "tag1", name: "Tag 1"),
            .init(id: "tag2", name: "Tag 2")
        ], accountId: account1)

        let repo = makeRepository(accountEmails: [account1], pool: pool)
        let tags = try await repo.loadCalendarTags().values.first(where: { _ in true })

        #expect(tags?.map(\.id).sorted() == ["tag1", "tag2"])
    }

    @Test func loadEvents_withSingleAccount_returnsEventsWithAccountId() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(pool: pool)
        let event = GoogleCalendar.Event("ev1", "cal1", accountId: account1, name: "event", colorId: nil, time: .at(50))
        let origin = GoogleCalendar.EventOrigin(id: "ev1", summary: "event")
        let list = GoogleCalendar.EventOriginValueList() |> \.items .~ [origin]
        try await storage.updateEvents("cal1", list, [event], accountId: account1)

        let repo = makeRepository(accountEmails: [account1], pool: pool)
        let events = try await repo.loadEvents("cal1", in: 0..<100).values.first(where: { _ in true })

        #expect(events?.count == 1)
        #expect(events?.first?.eventId == "ev1")
        #expect(events?.first?.accountId == account1)
    }

    @Test func loadEventDetail_withSingleAccount_returnsDetail() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(pool: pool)
        let origin = GoogleCalendar.EventOrigin(id: "event1", summary: "Some Event")
        try await storage.updateEventDetail("cal1", "Asia/Seoul", origin, accountId: account1)

        let repo = makeRepository(accountEmails: [account1], pool: pool)
        let detail = try await repo.loadEventDetail("cal1", "Asia/Seoul", "event1").values.first(where: { _ in true })

        #expect(detail?.id == "event1")
    }
}


// MARK: - 복수 계정 집계

extension GoogleCalendarLocalAggregatedRepositoryImpleTests {

    @Test func loadColors_withMultipleAccounts_mergesColors() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(pool: pool)
        try await storage.updateColors(.init(
            ownerId: account1,
            calendars: ["c1": .init(foregroundHex: "f1", backgroudHex: "b1")],
            events: [:]
        ), accountId: account1)
        try await storage.updateColors(.init(
            ownerId: account2,
            calendars: ["c2": .init(foregroundHex: "f2", backgroudHex: "b2")],
            events: ["e1": .init(foregroundHex: "f3", backgroudHex: "b3")]
        ), accountId: account2)

        let repo = makeRepository(accountEmails: [account1, account2], pool: pool)
        let colors = try await repo.loadColors().values.first(where: { _ in true })

        #expect(colors?.calendars.keys.sorted() == ["c1", "c2"])
        #expect(colors?.events.keys.sorted() == ["e1"])
    }

    @Test func loadCalendarTags_withMultipleAccounts_mergesTags() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(pool: pool)
        try await storage.updateCalendarList([
            .init(id: "tag1", name: "Tag 1")
        ], accountId: account1)
        try await storage.updateCalendarList([
            .init(id: "tag2", name: "Tag 2"),
            .init(id: "tag3", name: "Tag 3")
        ], accountId: account2)

        let repo = makeRepository(accountEmails: [account1, account2], pool: pool)
        let tags = try await repo.loadCalendarTags().values.first(where: { _ in true })

        #expect(tags?.map(\.id).sorted() == ["tag1", "tag2", "tag3"])
    }

    @Test func loadEvents_withMultipleAccounts_returnsEventsWithCorrectAccountId() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        let storage = localStorage(pool: pool)
        // account1에 이벤트 저장
        let event1 = GoogleCalendar.Event("ev1", "cal1", accountId: account1, name: "e1", colorId: nil, time: .at(50))
        let origin1 = GoogleCalendar.EventOrigin(id: "ev1", summary: "e1")
        let list1 = GoogleCalendar.EventOriginValueList() |> \.items .~ [origin1]
        try await storage.updateEvents("cal1", list1, [event1], accountId: account1)
        // account2에 이벤트 저장
        let event2 = GoogleCalendar.Event("ev2", "cal1", accountId: account2, name: "e2", colorId: nil, time: .at(60))
        let origin2 = GoogleCalendar.EventOrigin(id: "ev2", summary: "e2")
        let list2 = GoogleCalendar.EventOriginValueList() |> \.items .~ [origin2]
        try await storage.updateEvents("cal1", list2, [event2], accountId: account2)

        let repo = makeRepository(accountEmails: [account1, account2], pool: pool)
        let events = try await repo.loadEvents("cal1", in: 0..<100).values.first(where: { _ in true })

        let sorted = events?.sorted(by: { $0.eventId < $1.eventId })
        #expect(sorted?.count == 2)
        #expect(sorted?[0].eventId == "ev1")
        #expect(sorted?[0].accountId == account1)
        #expect(sorted?[1].eventId == "ev2")
        #expect(sorted?[1].accountId == account2)
    }

    @Test func loadEventDetail_withMultipleAccounts_findsAcrossAccounts() async throws {
        defer { cleanup() }
        let pool = try await makePool()
        defer { Task { try? await pool.close(serviceId: googleServiceId) } }

        // account2에만 event2 저장
        let origin = GoogleCalendar.EventOrigin(id: "event2", summary: "Event in account2")
        try await localStorage(pool: pool).updateEventDetail("cal1", "Asia/Seoul", origin, accountId: account2)

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

    func removeAccount(for serviceIdentifier: String, accountId: String) async throws { }
}
