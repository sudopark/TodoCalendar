//
//  AppleCalendarLocalStorageTests.swift
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


@Suite("AppleCalendarLocalStorageTests", .serialized)
final class AppleCalendarLocalStorageTests: PublisherWaitable, LocalTestable {

    var cancelBag: Set<AnyCancellable>! = []
    let sqliteService: SQLiteService = .init()

    private func makeStorage() -> AppleCalendarLocalStorageImple {
        let pool = StubExternalCalendarConnectionPool(sqliteService)
        return AppleCalendarLocalStorageImple(connectionPool: pool)
    }

    private func dummyTags() -> [AppleCalendar.Tag] {
        return [
            .init(id: "cal-1", name: "Calendar 1", colorHex: "FF0000"),
            .init(id: "cal-2", name: "Calendar 2", colorHex: "00FF00"),
            .init(id: "cal-3", name: "Calendar 3", colorHex: nil)
        ]
    }

    private func dummyEvents(for period: Range<TimeInterval>) -> [AppleCalendar.Event] {
        let mid = (period.lowerBound + period.upperBound) / 2
        return [
            .init(
                eventId: "event-1",
                calendarId: "cal-1",
                name: "Event 1",
                eventTime: .period(period.lowerBound..<mid),
                location: "Seoul"
            ),
            .init(
                eventId: "event-2",
                calendarId: "cal-2",
                name: "Event 2",
                eventTime: .allDay(mid..<period.upperBound, secondsFromGMT: 32400),
                location: nil
            )
        ]
    }
}


// MARK: - tag 저장 / 로드

extension AppleCalendarLocalStorageTests {

    @Test func tags_saveAndLoad() async throws {
        try await runTestWithOpenClose("apple_tags_1") { [self] in
            // given
            let storage = self.makeStorage()
            let tags = self.dummyTags()

            // when
            try await storage.saveCalendarTags(tags)
            let loaded = try await storage.loadCalendarTags()

            // then
            #expect(loaded.count == tags.count)
            #expect(loaded.map(\.id).sorted() == tags.map(\.id).sorted())
        }
    }

    @Test func tags_save_replacesExisting() async throws {
        try await runTestWithOpenClose("apple_tags_2") { [self] in
            // given
            let storage = self.makeStorage()
            let oldTags = self.dummyTags()
            let newTags: [AppleCalendar.Tag] = [.init(id: "cal-new", name: "New", colorHex: nil)]

            // when
            try await storage.saveCalendarTags(oldTags)
            try await storage.saveCalendarTags(newTags)
            let loaded = try await storage.loadCalendarTags()

            // then
            #expect(loaded.count == 1)
            #expect(loaded.first?.id == "cal-new")
        }
    }
}


// MARK: - event 저장 / 로드

extension AppleCalendarLocalStorageTests {

    @Test func events_saveAndLoad() async throws {
        try await runTestWithOpenClose("apple_events_1") { [self] in
            // given
            let storage = self.makeStorage()
            let period: Range<TimeInterval> = 0..<1000
            let events = self.dummyEvents(for: period)

            // when
            try await storage.saveEvents(events, in: period)
            let loaded = try await storage.loadEvents(in: period)

            // then
            #expect(loaded.count == events.count)
            #expect(Set(loaded.map(\.eventId)) == Set(events.map(\.eventId)))
        }
    }

    @Test func events_save_replacesOverlappingEvents() async throws {
        try await runTestWithOpenClose("apple_events_2") { [self] in
            // given
            let storage = self.makeStorage()
            let period: Range<TimeInterval> = 0..<1000
            let oldEvents = self.dummyEvents(for: period)
            let newEvent = AppleCalendar.Event(
                eventId: "event-new",
                calendarId: "cal-1",
                name: "New Event",
                eventTime: .period(100..<900),
                location: nil
            )

            // when
            try await storage.saveEvents(oldEvents, in: period)
            try await storage.saveEvents([newEvent], in: period)
            let loaded = try await storage.loadEvents(in: period)

            // then
            #expect(loaded.count == 1)
            #expect(loaded.first?.eventId == "event-new")
        }
    }

    @Test func events_loadByPeriod_returnsOnlyOverlapping() async throws {
        try await runTestWithOpenClose("apple_events_3") { [self] in
            // given
            let storage = self.makeStorage()
            let saveRange: Range<TimeInterval> = 0..<2000
            let events = [
                AppleCalendar.Event(
                    eventId: "event-a",
                    calendarId: "cal-1",
                    name: "A",
                    eventTime: .period(0..<500)
                ),
                AppleCalendar.Event(
                    eventId: "event-b",
                    calendarId: "cal-1",
                    name: "B",
                    eventTime: .period(1500..<2000)
                )
            ]
            try await storage.saveEvents(events, in: saveRange)

            // when
            let loaded = try await storage.loadEvents(in: 0..<600)

            // then
            #expect(loaded.count == 1)
            #expect(loaded.first?.eventId == "event-a")
        }
    }
}


// MARK: - resetAll

extension AppleCalendarLocalStorageTests {

    @Test func resetAll_clearsTagsAndEvents() async throws {
        try await runTestWithOpenClose("apple_reset_1") { [self] in
            // given
            let storage = self.makeStorage()
            let period: Range<TimeInterval> = 0..<1000
            try await storage.saveCalendarTags(self.dummyTags())
            try await storage.saveEvents(self.dummyEvents(for: period), in: period)

            // when
            try await storage.resetAll()
            let tags = try await storage.loadCalendarTags()
            let events = try await storage.loadEvents(in: period)

            // then
            #expect(tags.isEmpty)
            #expect(events.isEmpty)
        }
    }
}


// MARK: - Helpers

private final class StubExternalCalendarConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {
    private let service: SQLiteService
    init(_ service: SQLiteService) { self.service = service }
    func hasConnection(serviceId: String) async -> Bool { true }
    func connection(serviceId: String) async throws -> SQLiteService { service }
}
