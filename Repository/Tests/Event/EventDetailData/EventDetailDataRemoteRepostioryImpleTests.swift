//
//  EventDetailDataRemoteRepostioryImpleTests.swift
//  Repository
//
//  Created by sudo.park on 4/7/24.
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


class EventDetailDataRemoteRepostioryImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRemote: StubRemoteAPI!
    private var spyCache: SpyCache!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRemote = .init(responses: self.response)
        self.spyCache = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyCache = nil
        self.stubRemote = nil
        self.cancelBag = nil
    }
    
    private func makeRepository() -> EventDetailDataRemoteRepostioryImple {
        return .init(remoteAPI: self.stubRemote, cacheStorage: self.spyCache)
    }
}

extension EventDetailDataRemoteRepostioryImpleTests {
    
    private func makeRepositoryWithStubbing(
        _ stubbing: (StubRemoteAPI, SpyCache) -> Void = { _, _ in }
    ) -> EventDetailDataRemoteRepostioryImple {
        stubbing(self.stubRemote, self.spyCache)
        return self.makeRepository()
    }
    
    func testRepository_loadDetail() {
        // given
        let expect = expectation(description: "load detail - cache + remote")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.loadDetail("some")
        let details = self.waitOutputs(expect, for: loading, timeout: 0.01)
        
        // then
        XCTAssertEqual(details.count, 2)
        XCTAssertEqual(self.spyCache.didSaveDetailEventId, "some")
        
        let refreshed = details.last
        XCTAssertEqual(refreshed?.eventId, "some")
        XCTAssertEqual(refreshed?.place?.coordinate.latttude, 100.1)
        XCTAssertEqual(refreshed?.place?.coordinate.longitude, 300.3)
        XCTAssertEqual(refreshed?.place?.placeName, "place name")
        XCTAssertEqual(refreshed?.place?.addressText, "address")
        XCTAssertEqual(refreshed?.url, "some url")
        XCTAssertEqual(refreshed?.memo, "some")
    }
    
    func testRepository_whenLoadDetailFailsFromCache_ignore() {
        // given
        let expect = expectation(description: "캐시에서 조회 실패해도 무시하고 조회")
        let repository = self.makeRepositoryWithStubbing {
            $1.shouldFailLoadDetail = true
        }
        
        // when
        let loading = repository.loadDetail("some")
        let details = self.waitOutputs(expect, for: loading, timeout: 0.01)
        
        // then
        XCTAssertEqual(details.count, 1)
    }
    
    func testRepository_loadDetailFail() {
        // given
        let expect = expectation(description: "load fail")
        let repository = self.makeRepositoryWithStubbing { remote, _ in
            remote.shouldFailRequest = true
        }
        
        // when
        let loading = repository.loadDetail("some")
        let error = self.waitError(expect, for: loading)
        
        // then
        XCTAssertNotNil(error)
    }
    
    func testRepository_saveDetail() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let detail = EventDetailData("some")
        let _ = try await repository.saveDetail(detail)
        
        // then
        XCTAssertEqual(self.spyCache.didSaveDetailEventId, "some")
    }
    
    func testRepository_removeDetail() async throws{
        // given
        let repository = self.makeRepository()
        
        // when
        try await repository.removeDetail("some")
        
        // then
        XCTAssertEqual(self.spyCache.didRemoveDetailId, "some")
    }
}


extension EventDetailDataRemoteRepostioryImpleTests {
    
    private func singleDetailResponse(
        id: String = "some", memo: String = "some"
    ) -> String {
        return """
        {
            "eventId": "\(id)",
            "place": {
                "coordinate": {
                    "lat": 100.1, "long": 300.3
                },
                "name": "place name",
                "address": "address"
            },
            "url": "some url",
            "memo": "\(memo)"
        }
        """
    }
    
    private var response: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: EventDetailEndpoints.detail(eventId: "some"),
                resultJsonString: .success(self.singleDetailResponse())
            ),
            .init(
                method: .put,
                endpoint: EventDetailEndpoints.detail(eventId: "some"),
                resultJsonString: .success(self.singleDetailResponse(memo: "refreshed"))
            ),
            .init(
                method: .delete,
                endpoint: EventDetailEndpoints.detail(eventId: "some"),
                resultJsonString: .success("{ \"status\": \"ok\" }")
            )
        ]
    }
}

private class SpyCache: EventDetailDataLocalStorage, @unchecked Sendable {
    
    func loadAll() async throws -> [EventDetailData] {
        return []
    }
    
    var shouldFailLoadDetail: Bool = false
    func loadDetail(_ id: String) async throws -> EventDetailData? {
        guard self.shouldFailLoadDetail == false
        else {
            throw RuntimeError("failed")
        }
        let detail = EventDetailData(id)
            |> \.memo .~ "cached"
        return detail
    }
    
    var didSaveDetailEventId: String?
    func saveDetail(_ detail: EventDetailData) async throws {
        self.didSaveDetailEventId = detail.eventId
    }
    
    var didRemoveDetailId: String?
    func removeDetail(_ id: String) async throws {
        self.didRemoveDetailId = id
    }
    
    var didRemoveAll: Bool?
    func removeAll() async throws {
        self.didRemoveAll = true
    }
}
