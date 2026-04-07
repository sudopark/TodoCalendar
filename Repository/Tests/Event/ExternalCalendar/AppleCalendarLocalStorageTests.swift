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

    private func dummyOrigins(for period: Range<TimeInterval>) -> [AppleCalendar.EventOrigin] {
        let mid = (period.lowerBound + period.upperBound) / 2
        var origin1 = AppleCalendar.EventOrigin(
            eventId: "event-1", originalEventId: "event-1",
            calendarId: "cal-1", name: "Event 1",
            eventTime: .period(period.lowerBound..<mid)
        )
        origin1.location = "Seoul"
        origin1.recurrenceRules = ["RRULE:FREQ=WEEKLY;INTERVAL=1"]
        origin1.url = "https://example.com"
        origin1.notes = "some notes"

        var origin2 = AppleCalendar.EventOrigin(
            eventId: "event-2", originalEventId: "event-2",
            calendarId: "cal-2", name: "Event 2",
            eventTime: .allDay(mid..<period.upperBound, secondsFromGMT: 32400)
        )
        var attendee = AppleCalendar.Attendee(name: "Alice", email: "alice@example.com")
        attendee.isOrganizer = true
        attendee.status = .accepted
        origin2.attendees = [attendee]

        return [origin1, origin2]
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


// MARK: - EventOrigin 저장 / 로드

extension AppleCalendarLocalStorageTests {

    @Test func saveOrigins_thenLoadEvents_returnsLightweight() async throws {
        try await runTestWithOpenClose("apple_events_1") { [self] in
            // given
            let storage = self.makeStorage()
            let period: Range<TimeInterval> = 0..<1000
            let origins = self.dummyOrigins(for: period)

            // when
            try await storage.saveEventOrigins(origins, in: period)
            let loaded = try await storage.loadEvents(in: period)

            // then
            #expect(loaded.count == origins.count)
            #expect(Set(loaded.map(\.eventId)) == Set(origins.map(\.eventId)))
            // location은 포함
            #expect(loaded.first(where: { $0.eventId == "event-1" })?.location == "Seoul")
            // recurrenceRules/attendees/url/notes는 Event에 없음
        }
    }

    @Test func saveOrigins_thenLoadEventOrigin_returnsFullData() async throws {
        try await runTestWithOpenClose("apple_events_2") { [self] in
            // given
            let storage = self.makeStorage()
            let period: Range<TimeInterval> = 0..<1000
            let origins = self.dummyOrigins(for: period)
            try await storage.saveEventOrigins(origins, in: period)

            // when
            let loaded = try await storage.loadEventOrigin(id: "event-1")

            // then
            let result = try #require(loaded)
            #expect(result.eventId == "event-1")
            #expect(result.location == "Seoul")
            #expect(result.recurrenceRules == ["RRULE:FREQ=WEEKLY;INTERVAL=1"])
            #expect(result.url == "https://example.com")
            #expect(result.notes == "some notes")
        }
    }

    @Test func saveOrigins_thenLoadEventOrigin_withAttendees() async throws {
        try await runTestWithOpenClose("apple_events_3") { [self] in
            // given
            let storage = self.makeStorage()
            let period: Range<TimeInterval> = 0..<1000
            let origins = self.dummyOrigins(for: period)
            try await storage.saveEventOrigins(origins, in: period)

            // when
            let loaded = try await storage.loadEventOrigin(id: "event-2")

            // then
            let result = try #require(loaded)
            #expect(result.attendees.count == 1)
            #expect(result.attendees.first?.name == "Alice")
            #expect(result.attendees.first?.email == "alice@example.com")
            #expect(result.attendees.first?.isOrganizer == true)
            #expect(result.attendees.first?.status == .accepted)
        }
    }

    @Test func saveOrigins_replacesOverlappingEvents() async throws {
        try await runTestWithOpenClose("apple_events_4") { [self] in
            // given
            let storage = self.makeStorage()
            let period: Range<TimeInterval> = 0..<1000
            let oldOrigins = self.dummyOrigins(for: period)
            var newOrigin = AppleCalendar.EventOrigin(
                eventId: "event-new", originalEventId: "event-new",
                calendarId: "cal-1", name: "New Event",
                eventTime: .period(100..<900)
            )
            newOrigin.url = "https://new.com"

            // when
            try await storage.saveEventOrigins(oldOrigins, in: period)
            try await storage.saveEventOrigins([newOrigin], in: period)
            let loaded = try await storage.loadEvents(in: period)

            // then
            #expect(loaded.count == 1)
            #expect(loaded.first?.eventId == "event-new")
        }
    }

    @Test func loadEventOrigin_whenNotExist_returnsNil() async throws {
        try await runTestWithOpenClose("apple_events_5") { [self] in
            // given
            let storage = self.makeStorage()

            // when
            let loaded = try await storage.loadEventOrigin(id: "nonexistent")

            // then
            #expect(loaded == nil)
        }
    }

    @Test func loadEvents_returnsOnlyOverlappingPeriod() async throws {
        try await runTestWithOpenClose("apple_events_6") { [self] in
            // given
            let storage = self.makeStorage()
            let saveRange: Range<TimeInterval> = 0..<2000
            var originA = AppleCalendar.EventOrigin(
                eventId: "event-a", originalEventId: "event-a",
                calendarId: "cal-1", name: "A",
                eventTime: .period(0..<500)
            )
            var originB = AppleCalendar.EventOrigin(
                eventId: "event-b", originalEventId: "event-b",
                calendarId: "cal-1", name: "B",
                eventTime: .period(1500..<2000)
            )
            try await storage.saveEventOrigins([originA, originB], in: saveRange)

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
            try await storage.saveEventOrigins(self.dummyOrigins(for: period), in: period)

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
