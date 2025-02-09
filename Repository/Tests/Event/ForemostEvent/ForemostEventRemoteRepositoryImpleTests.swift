//
//  ForemostEventRemoteRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 6/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Repository


class ForemostEventRemoteRepositoryImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyStorage: StubForemostLocalStorage!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyStorage = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyStorage = nil
    }
    
    private func makeRepository(
        _ stubbing: ((StubForemostLocalStorage, StubRemoteAPI) -> Void)? = nil
    ) -> ForemostEventRemoteRepositoryImple {
        let remote = StubRemoteAPI(responses: self.responses)
        self.spyStorage.stubForemost = TodoEvent(uuid: "todo", name: "cached")
        stubbing?(self.spyStorage, remote)
        return .init(remote: remote, cacheStorage: self.spyStorage)
    }
}


extension ForemostEventRemoteRepositoryImpleTests {
    
    // load foremost event
    func testRepository_loadForemostTodoEvent() {
        // given
        let expect = expectation(description: "load foremost event")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let load = repository.foremostEvent()
        let events = self.waitOutputs(expect, for: load, timeout: 0.1)
        
        // then
        let names = events.compactMap { $0 as? TodoEvent }.map { $0.name }
        XCTAssertEqual(names, [
            "cached", "refreshed"
        ])
        
        XCTAssertEqual((self.spyStorage.stubForemost as? TodoEvent)?.name, "refreshed")
    }
    
    // load foremost event: cache fail -> ignore
    func testRepository_whenLoadForemostAndCacheFails_ignore() {
        // given
        let expect = expectation(description: "load foremost event: cache fail -> ignore")
        let repository = self.makeRepository { cache, _ in
            cache.shouldFailLoad = true
        }
        
        // when
        let load = repository.foremostEvent()
        let events = self.waitOutputs(expect, for: load, timeout: 0.1)
        
        // then
        let names = events.compactMap { $0 as? TodoEvent }.map { $0.name }
        XCTAssertEqual(names, [
            "refreshed"
        ])
        
        XCTAssertEqual((self.spyStorage.stubForemost as? TodoEvent)?.name, "refreshed")
    }
    
    // load foremost event: remote fail -> fail
    func testRepository_whenLoadForemostAndRemoteFail_isFail() {
        // given
        let expect = expectation(description: "load foremost event: remote fail -> fail")
        let reposiotry = self.makeRepository { _, remote in
            remote.shouldFailRequest = true
        }
        
        // when
        let load = reposiotry.foremostEvent()
        let error = self.waitError(expect, for: load)
        
        // then
        XCTAssertNotNil(error)
    }
    
    // update foremost event + replace cache
    func testRepository_updateForemostAndReplaceCache() async throws {
        // given
        let repository = self.makeRepository()
        let cachedBeforeUpdate = self.spyStorage.stubForemost
        
        // when
        let updated = try await repository.updateForemostEvent(.init("some", false))
        
        // then
        XCTAssertEqual(updated.eventId, "schedule")
        XCTAssertEqual(updated is ScheduleEvent, true)
        let cachedAfterUpdate = self.spyStorage.stubForemost
        XCTAssertEqual(cachedBeforeUpdate is TodoEvent, true)
        XCTAssertEqual(cachedAfterUpdate is ScheduleEvent, true)
    }
    
    // remove foremost event
    func testRepository_removeForemost() async throws {
        // given
        let repository = self.makeRepository()
        let cachedBeforeRemove = self.spyStorage.stubForemost
        
        // when
        try await repository.removeForemostEvent()
        
        // then
        let cachedAfterRemove = self.spyStorage.stubForemost
        XCTAssertNotNil(cachedBeforeRemove)
        XCTAssertNil(cachedAfterRemove)
    }
}

private extension ForemostEventRemoteRepositoryImpleTests {
    
    private var dummySingleTodoResponse: String {
        return """
        {
            "uuid": "todo",
            "name": "refreshed",
            "event_tag_id": "custom_id",
            "repeating": {
                "start": 300,
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
            ]
        }
        """
    }
    
    private var dummySingleScheduleEvent: String {
        return """
        {
            "uuid": "schedule",
            "name": "refreshed",
            "event_tag_id": "custom_id",
            "event_time": {
                "time_type": "allday",
                "period_start": 0,
                "period_end": 100,
                "seconds_from_gmt": 300
            },
            "repeating": {
                "start": 300,
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
    
    private var foremostEventResponse: String {
        return """
        {
            "event_id": "some",
            "is_todo": true,
            "event": \(self.dummySingleTodoResponse)
        }
        """
    }
    
    private var updateForemostEventIdResponse: String {
        return """
        {
            "event_id": "some",
            "is_todo": false,
            "event": \(self.dummySingleScheduleEvent)
        }
        """
    }
    
    private var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: ForemostEventEndpoints.event,
                resultJsonString: .success(self.foremostEventResponse)
            ),
            .init(
                method: .put,
                endpoint: ForemostEventEndpoints.event,
                resultJsonString: .success(self.updateForemostEventIdResponse)
            ),
            .init(
                method: .delete,
                endpoint: ForemostEventEndpoints.event,
                resultJsonString: .success("{ \"status\": \"ok\" }")
            )
        ]
    }
}

private class StubForemostLocalStorage: ForemostLocalStorage, @unchecked Sendable {
    
    var stubForemost: (any ForemostMarkableEvent)?
    
    var shouldFailLoad: Bool = false
    func loadForemostEvent() async throws -> (any ForemostMarkableEvent)? {
        guard self.shouldFailLoad == false
        else {
            throw RuntimeError("failed")
        }
        return self.stubForemost
    }
    
    func loadForemostEvent(_ eventId: ForemostEventId) async throws -> (any ForemostMarkableEvent)? {
        return self.stubForemost
    }
    
    func updateForemostEvent(_ event: any ForemostMarkableEvent) async throws {
        self.stubForemost = event
    }
    
    func updateForemostEventId(_ eventId: ForemostEventId) async throws {
        if eventId.isTodo {
            self.stubForemost = TodoEvent.dummy()
        } else {
            self.stubForemost = ScheduleEvent(uuid: "some", name: "name", time: .at(1))
        }
    }
    
    func removeForemostEvent() async throws {
        self.stubForemost = nil
    }
}
