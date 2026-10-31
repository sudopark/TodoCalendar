//
//  EventTimeLocalStorageImpleTests.swift
//  EventDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SQLiteService
import UnitTestHelpKit
import DBInfraInterface
import DBInfraTesting
import EventDomainInterface
@testable import EventDomain


final class EventTimeLocalStorageImpleTests: BaseLocalTests {

    private var storage: EventTimeLocalStorageImple!

    override func setUpWithError() throws {
        self.fileName = "event_time_local_storage"
        try super.setUpWithError()
        self.storage = EventTimeLocalStorageImple(
            connectionPool: PrivateConnectionPool(self.sqliteService), serviceId: "service"
        )
    }

    override func tearDownWithError() throws {
        self.storage = nil
        try super.tearDownWithError()
    }

    private var inside: EventTime { .period(100..<200) }
    private var outside: EventTime { .period(500..<600) }
    private var allDay: EventTime { .allDay(150..<250, secondsFromGMT: 9 * 3600) }
}


extension EventTimeLocalStorageImpleTests {

    func testStorage_loadTimesOverlappingRange_returnsOnlyOverlappingEvents() async throws {
        // given
        try await self.storage.saveTimes(["in": self.inside, "out": self.outside])

        // when
        let times = try await self.storage.loadTimes(overlapping: 150..<300)

        // then
        XCTAssertEqual(times, ["in": self.inside])
    }

    func testStorage_loadTime_returnsSavedTimeOrNil() async throws {
        // given
        try await self.storage.saveTimes(["all_day": self.allDay])

        // when
        let saved = try await self.storage.loadTime(eventId: "all_day")
        let missing = try await self.storage.loadTime(eventId: "missing")

        // then
        XCTAssertEqual(saved, self.allDay)
        XCTAssertNil(missing)
    }

    func testStorage_saveTimesWithSameEventId_replacesTime() async throws {
        // given
        try await self.storage.saveTimes(["id": self.inside])

        // when
        try await self.storage.saveTimes(["id": self.outside])

        // then
        let time = try await self.storage.loadTime(eventId: "id")
        XCTAssertEqual(time, self.outside)
    }

    func testStorage_removeTimes_removesOnlyGivenEvents() async throws {
        // given
        try await self.storage.saveTimes(["a": self.inside, "b": self.inside])

        // when
        try await self.storage.removeTimes(eventIds: ["a"])

        // then
        let times = try await self.storage.loadTimes(overlapping: 0..<1000)
        XCTAssertEqual(Set(times.keys), ["b"])
    }

    func testStorage_removeAllTimes_removesEveryEvent() async throws {
        // given
        try await self.storage.saveTimes(["a": self.inside, "b": self.outside])

        // when
        try await self.storage.removeAllTimes()

        // then
        let times = try await self.storage.loadTimes(overlapping: 0..<1000)
        XCTAssertTrue(times.isEmpty)
    }
}


private final class PrivateConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {

    private let service: SQLiteService
    init(_ service: SQLiteService) { self.service = service }

    func hasConnection(serviceId: String) async -> Bool { true }
    func connection(serviceId: String) async throws -> SQLiteService { self.service }
}
