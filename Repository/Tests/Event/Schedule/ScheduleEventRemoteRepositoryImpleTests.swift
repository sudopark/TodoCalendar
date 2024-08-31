//
//  ScheduleEventRemoteRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 4/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository

private let refTime = Date().timeIntervalSince1970

class ScheduleEventRemoteRepositoryImpleTests: BaseTestCase, PublisherWaitable {
    
    private var stubRemote: StubRemoteAPI!
    private var spyCache: SpyScheduleEventLocalStorage!
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.stubRemote = .init(responses: self.response)
        self.spyCache = .init()
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.stubRemote = nil
        self.spyCache = nil
        self.cancelBag = nil
    }
    
    private func makeRepository(
        customStubbing: ((SpyScheduleEventLocalStorage, StubRemoteAPI) -> Void)? = nil
    ) -> ScheduleEventRemoteRepositoryImple {
        customStubbing?(self.spyCache, self.stubRemote)
        return ScheduleEventRemoteRepositoryImple(
            remote: self.stubRemote, cacheStore: self.spyCache
        )
    }
    
    private var dummyRepeating: EventRepeating {
        return EventRepeating(
            repeatingStartTime: 300,
            repeatOption: EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!) |> \.dayOfWeeks .~ [.sunday]
        )
        |> \.repeatingEndTime .~ 400
        
    }
    
    private var dummyNotificationOption: EventNotificationTimeOption {
        return .allDay9AMBefore(seconds: 300)
    }
    
    private var dummyMakeParams: ScheduleMakeParams {
        return ScheduleMakeParams()
            |> \.name .~ "name"
            |> \.eventTagId .~ .custom("custom_id")
            |> \.time .~ .allDay(0..<100, secondsFromGMT: 300)
            |> \.repeating .~ pure(self.dummyRepeating)
            |> \.notificationOptions .~ [self.dummyNotificationOption]
            |> \.showTurn .~ true
    }
    
    private func assertEvent(_ event: ScheduleEvent) {
        XCTAssertEqual(event.uuid, "new_uuid")
        XCTAssertEqual(event.name, "refreshed")
        XCTAssertEqual(event.eventTagId, .custom("custom_id"))
        XCTAssertEqual(event.time, .allDay(refTime+100..<refTime+200, secondsFromGMT: 300))
        XCTAssertEqual(event.repeating?.repeatingStartTime, 300)
        XCTAssertEqual(event.repeating?.repeatOption.compareHash, self.dummyRepeating.repeatOption.compareHash)
        XCTAssertEqual(event.repeating?.repeatingEndTime, refTime+3600*24*100)
        XCTAssertEqual(event.notificationOptions, [.allDay9AMBefore(seconds: 300)])
        XCTAssertEqual(event.showTurn, true)
    }
}

extension ScheduleEventRemoteRepositoryImpleTests {
    
    func testRepository_makeEvent() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let event = try await repository.makeScheduleEvent(self.dummyMakeParams)
        
        // then
        self.assertEvent(event)
        XCTAssertEqual(self.spyCache.didSaveEvent?.uuid, "new_uuid")
    }
    
    // update + update cache
    func testRepository_updateEvent() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = SchedulePutParams()
            |> \.name .~ "some"
            |> \.time .~ .at(0)
        let updated = try await repository.updateScheduleEvent("edit", params)
        
        // then
        self.assertEvent(updated)
        XCTAssertEqual(self.spyCache.didUpdateEvents?.first?.uuid, updated.uuid)
    }
}

extension ScheduleEventRemoteRepositoryImpleTests {
    
    func testRepository_excludeRepeatingEvent() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try await repository.excludeRepeatingEvent(
            "origin_repeating", at: .at(200), asNew: self.dummyMakeParams
        )
        
        // then
        XCTAssertEqual(result.originEvent.uuid, "origin_repeating")
        XCTAssertEqual(result.originEvent.repeatingTimeToExcludes, ["100"])
        self.assertEvent(result.newEvent)
        let params = self.stubRemote.didRequestedParams ?? [:]
        let new = params["new"] as? [String: Any]
        let excludeTime = params["exclude_repeatings"] as? String
        XCTAssertNotNil(new)
        XCTAssertNotNil(excludeTime)
        XCTAssertEqual(self.spyCache.didUpdateEvents?.first?.uuid, "origin_repeating")
        XCTAssertEqual(self.spyCache.didSaveEvent?.uuid, "new_uuid")
    }
    
    func testRepository_removeRepeatingEventOnlyThisTime() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try await repository.removeEvent("origin", onlyThisTime: .at(100))
        
        // then
        XCTAssertEqual(result.nextRepeatingEvnet?.uuid, "origin")
        XCTAssertEqual(result.nextRepeatingEvnet?.repeatingTimeToExcludes, ["100"])
        XCTAssertEqual(self.spyCache.didUpdateEvents?.first?.uuid, "origin")
    }
    
    func testRepository_removeEvent() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try await repository.removeEvent("origin", onlyThisTime: nil)
        
        // then
        XCTAssertNotNil(result)
        XCTAssertNil(result.nextRepeatingEvnet)
        XCTAssertEqual(self.spyCache.didRemoveIds, ["origin"])
    }
}

extension ScheduleEventRemoteRepositoryImpleTests {
    
    // load events
    func testRepository_whenLoadEvents_loadCacheAndRemote() {
        // given
        let expect = expectation(description: "load events")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.loadScheduleEvents(in: 0..<100)
        let lists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let idLists = lists.map { es in es.map { $0.uuid } }
        XCTAssertEqual(idLists, [
            ["new_uuid", "should_remove"],
            ["new_uuid"]
        ])
    }
    
    // after load events + remove not exists at refreshed
    func testRepository_whenLoadEvents_replaceCache() {
        // given
        let expect = expectation(description: "after load events + remove not exists at refreshed")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        self.spyCache.didUpdateCallback = { expect.fulfill() }
        self.spyCache.didRemoveCallback = { expect.fulfill() }
        
        // when
        repository.loadScheduleEvents(in: 0..<100)
            .sink(receiveValue: { _ in })
            .store(in: &self.cancelBag)
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertEqual(
            self.spyCache.didUpdateEvents?.map { $0.name },
            ["refreshed"]
        )
        XCTAssertEqual(
            self.spyCache.didRemoveIds, 
            ["new_uuid" ,"should_remove"]
        )
    }
    
    // load events when load cache failed -> ignore cache
    func testRepository_whenLoadEvnetsAndLoadCacheFail_ignore() {
        // given
        let expect = expectation(description: "load events when load cache failed -> ignore cache")
        let repository = self.makeRepository { cache, _ in
            cache.shouldLoadEventsFail = true
        }
        
        // when
        let loading = repository.loadScheduleEvents(in: 0..<100)
        let lists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let nameLists = lists.map { es in es.map { $0.name } }
        XCTAssertEqual(nameLists, [
            ["refreshed"]
        ])
    }
    
    // load events from remote fail => fail
    func testRepository_whenLoadEventsAndLoadFromRemoteFailed_shouldFail() {
        // given
        let expect = expectation(description: "load events from remote fail => fail")
        let repository = self.makeRepository { _, remote in
            remote.shouldFailRequest = true
        }
        
        // when
        let loading = repository.loadScheduleEvents(in: 0..<100)
        let error = self.waitError(expect, for: loading)
        
        // then
        XCTAssertNotNil(error)
    }
    
    // load event
    func testRepository_whenLoadEvent_loadCacheAndRemote() {
        // given
        let expect = expectation(description: "load events")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.scheduleEvent("some")
        let lists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let idLists = lists.map { $0.name }
        XCTAssertEqual(idLists, [ "cached", "refreshed" ])
    }
    
    // after load event + remove not exists at refreshed
    func testRepository_whenLoadEvent_replaceCache() {
        // given
        let expect = expectation(description: "after load event + remove not exists at refreshed")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        self.spyCache.didUpdateCallback = { expect.fulfill() }
        self.spyCache.didRemoveCallback = { expect.fulfill() }
        
        // when
        repository.scheduleEvent("some")
            .sink(receiveValue: { _ in })
            .store(in: &self.cancelBag)
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertEqual(
            self.spyCache.didUpdateEvents?.map { $0.name },
            ["refreshed"]
        )
        XCTAssertEqual(
            self.spyCache.didRemoveIds,
            ["some"]
        )
    }
    
    // load event when load cache failed -> ignore cache
    func testRepository_whenLoadEvnetAndLoadCacheFail_ignore() {
        // given
        let expect = expectation(description: "load event when load cache failed -> ignore cache")
        let repository = self.makeRepository { cache, _ in
            cache.shouldFailLoadEvent = true
        }
        
        // when
        let loading = repository.scheduleEvent("some")
        let events = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let nameLists = events.map { $0.name }
        XCTAssertEqual(nameLists, [ "refreshed" ])
    }
    
    // load event from remote fail => fail
    func testRepository_whenLoadEventAndLoadFromRemoteFailed_shouldFail() {
        // given
        let expect = expectation(description: "load event from remote fail => fail")
        let repository = self.makeRepository { _, remote in
            remote.shouldFailRequest = true
        }
        
        // when
        let loading = repository.scheduleEvent("some")
        let error = self.waitError(expect, for: loading)
        
        // then
        XCTAssertNotNil(error)
    }
}

extension ScheduleEventRemoteRepositoryImpleTests {
    
    private var dummySingleEvent: String {
        return """
        {
            "uuid": "new_uuid",
            "name": "refreshed",
            "event_tag_id": "custom_id",
            "event_time": {
                "time_type": "allday",
                "period_start": \(refTime+100),
                "period_end": \(refTime+200),
                "seconds_from_gmt": 300
            },
            "repeating": {
                "start": 300,
                "end": \(refTime+3600*24*100),
                "option": {

                    "optionType": "every_week",
                    "interval": 1,
                    "dayOfWeek": [1],
                    "timeZone": "Asia/Seoul"
                }
            },
            "notification_options": [
                {
                    "type_text": "allDay9AMBefore",
                    "before_seconds": 300
                }
            ],
            "show_turns": true
        }
        """
    }
    
    private var response: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                method: .post,
                endpoint: ScheduleEventEndpoints.make,
                resultJsonString: .success(self.dummySingleEvent)
            ),
            .init(
                method: .put,
                endpoint: ScheduleEventEndpoints.schedule(id: "edit"),
                resultJsonString: .success(self.dummySingleEvent)
            ),
            .init(
                method: .post,
                endpoint: ScheduleEventEndpoints.exclude(id: "origin_repeating"),
                resultJsonString: .success("""
                {
                    "new_schedule": \(self.dummySingleEvent),
                    "updated_origin": {
                        "uuid": "origin_repeating",
                        "name": "origin",
                        "event_time": {
                            "time_type": "allday",
                            "period_start": \(refTime+100),
                            "period_end": \(refTime+200),
                            "seconds_from_gmt": 300
                        },
                        "exclude_repeatings": ["100"]
                    }
                }
                """)
            ),
            .init(
                method: .patch,
                endpoint: ScheduleEventEndpoints.exclude(id: "origin"),
                resultJsonString: .success("""
                {
                    "uuid": "origin",
                    "name": "origin",
                    "event_time": {
                        "time_type": "allday",
                        "period_start": \(refTime+100),
                        "period_end": \(refTime+200),
                        "seconds_from_gmt": 300
                    },
                    "exclude_repeatings": ["100"]
                }
                """)
            ),
            .init(
                method: .delete,
                endpoint: ScheduleEventEndpoints.schedule(id: "origin"),
                resultJsonString: .success("{}")
            ),
            .init(
                method: .get,
                endpoint: ScheduleEventEndpoints.schedules,
                resultJsonString: .success("[\(self.dummySingleEvent)]")
            ),
            .init(
                method: .get,
                endpoint: ScheduleEventEndpoints.schedule(id: "some"),
                resultJsonString: .success(self.dummySingleEvent)
            )
        ]
    }
}


private class SpyScheduleEventLocalStorage: ScheduleEventLocalStorage, @unchecked Sendable {
    
    func loadAllEvents() async throws -> [ScheduleEvent] {
        return []
    }
    
    var shouldFailLoadEvent: Bool = false
    func loadScheduleEvent(_ eventId: String) async throws -> ScheduleEvent {
        guard self.shouldFailLoadEvent == false
        else {
            throw RuntimeError("failed")
        }
        let event = ScheduleEvent(uuid: eventId, name: "cached", time: .at(100))
        return event
    }
    
    var shouldLoadEventsFail: Bool = false
    func loadScheduleEvents(in range: Range<TimeInterval>) async throws -> [ScheduleEvent] {
        guard self.shouldLoadEventsFail == false
        else {
            throw RuntimeError("failed")
        }
        let event = ScheduleEvent(uuid: "new_uuid", name: "cached", time: .at(100))
        let shouldRemove = ScheduleEvent(uuid: "should_remove", name: "remove", time: .at(100))
        return [event, shouldRemove]
    }
    
    var didSaveEvent: ScheduleEvent?
    func saveScheduleEvent(_ event: ScheduleEvent) async throws {
        self.didSaveEvent = event
    }
    
    var didUpdateEvents: [ScheduleEvent]?
    var didUpdateCallback: (() -> Void)?
    func updateScheduleEvents(_ events: [ScheduleEvent]) async throws {
        self.didUpdateEvents = events
        self.didUpdateCallback?()
    }
    
    var didRemoveIds: [String]?
    var didRemoveCallback: (() -> Void)?
    func removeScheduleEvents(_ eventIds: [String]) async throws {
        self.didRemoveIds = eventIds
        self.didRemoveCallback?()
    }
    
    func removeAll() async throws { }
}
