//
//  EventTagRemoteRepositoryImpleTests.swift
//  Repository
//
//  Created by sudo.park on 4/7/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import AsyncFlatMap
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


class EventTagRemoteRepositoryImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyCache: SpyLocalStorage!
    private var spyTodoCache: SpyTodoLocalStorage!
    private var spyScheduleCache: SpyScheduleEventLocalStorage!
    private var stubRemote: StubRemoteAPI!
    private var fakeEnvStore: FakeEnvironmentStorage!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyCache = .init()
        self.spyTodoCache = .init()
        self.spyScheduleCache = .init()
        self.fakeEnvStore = .init()
        self.stubRemote = .init(responses: self.response)
    }
    
    override func tearDownWithError() throws {
        self.spyCache = nil
        self.fakeEnvStore = nil
        self.stubRemote = nil
        self.cancelBag = nil
    }
    
    private func makeRepository() -> EventTagRemoteRepositoryImple {
        return .init(
            remote: self.stubRemote,
            cacheStorage: self.spyCache,
            todoCacheStorage: self.spyTodoCache,
            scheduleCacheStorage: self.spyScheduleCache,
            environmentStorage: self.fakeEnvStore
        )
    }
}

extension EventTagRemoteRepositoryImpleTests {
    
    func testRepository_makeNewTag() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = CustomEventTagMakeParams(name: "some", colorHex: "color")
        let tag = try await repository.makeNewTag(params)
        
        // then
        XCTAssertEqual(tag.uuid, "id")
        XCTAssertEqual(tag.name, "some")
        XCTAssertEqual(tag.colorHex, "color")
        
        XCTAssertEqual(self.spyCache.didSavrTag?.uuid, "id")
    }
    
    func testRepository_editTag() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = CustomEventTagEditParams(name: "new name", colorHex: "color")
        let tag = try await repository.editTag("id", params)
        
        // then
        XCTAssertEqual(tag.name, "new name")
        XCTAssertEqual(self.spyCache.didUpdateTags?.count, 1)
    }
    
    func testRepository_deleteTag_andDeleteOffIds() async throws {
        // given
        let repository = self.makeRepository()
        let _ = repository.toggleTagIsOn(.custom("origin"))
        let offIdsBeforeDelete = repository.loadOffTags()
        
        // when
        try await repository.deleteTag("origin")
        let offIdsAfterDelete = repository.loadOffTags()
        
        // then
        XCTAssertEqual(self.spyCache.didDeleteTagIds, ["origin"])
        XCTAssertEqual(offIdsBeforeDelete, [.custom("origin")])
        XCTAssertEqual(offIdsAfterDelete, [])
    }
    
    func testRepository_deleteTagWithEvents() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let result = try await repository.deleteTagWithAllEvents("t1")
        
        // then
        XCTAssertEqual(result.todoIds, ["todo1", "todo2"])
        XCTAssertEqual(result.scheduleIds, ["sc1", "sc2"])
        XCTAssertEqual(self.spyCache.didDeleteTagIds, ["t1"])
        XCTAssertEqual(self.spyTodoCache.didRemovedTodoIds, result.todoIds)
        XCTAssertEqual(self.spyScheduleCache.didRemoveIds, result.scheduleIds)
    }
}

extension EventTagRemoteRepositoryImpleTests {
    
    private func makeRepositoryWithStubbing(
        shouldFailRemote: Bool = false,
        stubCache: (SpyLocalStorage) -> Void = { _ in}
    ) -> EventTagRemoteRepositoryImple {
        self.stubRemote.shouldFailRequest = shouldFailRemote
        stubCache(self.spyCache)
        return self.makeRepository()
    }
    
    func testReposiotry_loadAllTags() {
        // given
        let expect = expectation(description: "all tag 조회시 cache, remote 순으로 조회, 조회 이후 캐시 덮어쓰기")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        let _ = repository.toggleTagIsOn(.custom("t1"))
        let _ = repository.toggleTagIsOn(.custom("t2"))
        
        // when
        let loading = repository.loadAllCustomTags()
        let tagLists = self.waitOutputs(expect, for: loading, timeout: 0.1)
        
        // then
        let idsFirst = tagLists.first.map { $0.map { $0.uuid }}
        XCTAssertEqual(idsFirst, ["t1", "t2", "t3"])
        let idsSecond = tagLists.last.map { $0.map { $0.uuid }}
        XCTAssertEqual(idsSecond, ["t1", "t3"])
        XCTAssertEqual(self.spyCache.didDeleteTagIds, ["t1", "t2", "t3"])
        XCTAssertEqual(self.spyCache.didUpdateTags?.map { $0.uuid }, ["t1", "t3"])
        
        let offTagIds = repository.loadOffTags()
        XCTAssertEqual(offTagIds, [.custom("t1")])
    }
    
    func testRepository_whenLoadtagAllAndcacheFails_ignore() {
        // given
        let expect = expectation(description: "all tag 조회시 캐시 조회 실패해도 무시")
        let repository = self.makeRepositoryWithStubbing { $0.shouldFailLoadAllTags = true }
        
        // when
        let loading = repository.loadAllCustomTags()
        let tagLists = self.waitOutputs(expect, for: loading)
        
        // then
        XCTAssertEqual(tagLists.count, 1)
        XCTAssertEqual(tagLists.first?.map{ $0.uuid }, ["t1", "t3"])
    }
    
    func testRepository_whenLoadTagAllAndRemoteFailed_fail() {
        // given
        let expect = expectation(description: "all tag 조회시 remote 조회 실패하면 실패")
        let repository = self.makeRepositoryWithStubbing(shouldFailRemote: true)
        
        // when
        let error = self.waitError(expect, for: repository.loadAllCustomTags())
        
        // then
        XCTAssertNotNil(error)
    }
    
    func testRepository_loadTags() {
        // given
        let expect = expectation(description: "ids로 태그 조회")
        expect.expectedFulfillmentCount = 2
        let repository = self.makeRepository()
        
        // when
        let loading = repository.loadCustomTags(["t1", "t3"])
        let tagLists = self.waitOutputs(expect, for: loading)
        
        // then
        XCTAssertEqual(tagLists.count, 2)
        XCTAssertEqual(self.spyCache.didDeleteTagIds, ["t1", "t3"])
        XCTAssertEqual(self.spyCache.didUpdateTags?.map { $0.uuid }, ["t1", "t3"])
    }
    
    func testRepository_whenLoadTagAndCacheFail_ignore() {
        // given
        let expect = expectation(description: "ids로 태그 조회시 캐시 실패하면 무시")
        let repository = self.makeRepositoryWithStubbing { $0.shouldFailLoadTags = true }
        
        // when
        let loading = repository.loadCustomTags(["t1", "t3"])
        let tagLists = self.waitOutputs(expect, for: loading)
        
        // then
        XCTAssertEqual(tagLists.count, 1)
    }
    
    func testRepository_whenLoadTagsFailFromRemote_fail() {
        // given
        let expect = expectation(description: "태그 조회 실패")
        let repository = self.makeRepositoryWithStubbing(shouldFailRemote: true)
        
        // when
        let loading = repository.loadCustomTags(["t1", "t3"])
        let error = self.waitError(expect, for: loading)
        
        // then
        XCTAssertNotNil(error)
    }
}

extension EventTagRemoteRepositoryImpleTests {
    
    private func singletagString(
        id: String = "id",
        name: String = "some"
    ) -> String {
        return """
        { "uuid": "\(id)", "name": "\(name)", "color_hex": "color" }
        """
    }
    
    private var response: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .post,
                endpoint: EventTagEndpoints.make,
                resultJsonString: .success(singletagString())),
            .init(
                method: .put,
                endpoint: EventTagEndpoints.tag(id: "id"),
                resultJsonString: .success(singletagString(name: "new name"))
            ),
            .init(
                method: .delete,
                endpoint: EventTagEndpoints.tag(id: "origin"),
                resultJsonString: .success("{ \"status\": \"ok\"}")
            ),
            .init(
                method: .delete,
                endpoint: EventTagEndpoints.tagAndEvents(id: "t1"),
                resultJsonString: .success(RemoveCustomEventTagWithEventsResult.dummyJSON())
            ),
            .init(
                method: .get,
                endpoint: EventTagEndpoints.allTags,
                resultJsonString: .success(
                    """
                    [
                        \(singletagString(id: "t1", name: "refreshed-1")),
                        \(singletagString(id: "t3", name: "refreshed-3"))
                    ]
                    """
                )
            ),
            .init(
                method: .get,
                endpoint: EventTagEndpoints.tags,
                resultJsonString: .success(
                    """
                    [
                        \(singletagString(id: "t1", name: "refreshed-1")),
                        \(singletagString(id: "t3", name: "refreshed-3"))
                    ]
                    """
                )
            )
        ]
    }
}

private extension RemoveCustomEventTagWithEventsResult {
    
    static func dummyJSON() -> String {
        return """
        { "todos": ["todo1", "todo2"], "schedules": ["sc1", "sc2"] }
        """
    }
}


private final class SpyLocalStorage: EventTagLocalStorage, @unchecked Sendable {
    
    var didSavrTag: CustomEventTag?
    func saveTag(_ tag: CustomEventTag) async throws {
        self.didSavrTag = tag
    }
    
    func editTag(_ uuid: String, with params: CustomEventTagEditParams) async throws {
        
    }
    
    var didUpdateTags: [CustomEventTag]?
    func updateTags(_ tags: [CustomEventTag]) async throws {
        self.didUpdateTags = tags
    }
    
    var didDeleteTagIds: [String]?
    func deleteTags(_ tagIds: [String]) async throws {
        self.didDeleteTagIds = tagIds
    }
    
    func loadTag(match name: String) async throws -> [CustomEventTag] {
        return []
    }
    
    var shouldFailLoadTags: Bool = false
    func loadTags(in ids: [String]) async throws -> [CustomEventTag] {
        guard shouldFailLoadTags == false
        else {
            throw RuntimeError("failed")
        }
        return ids.map {
            .init(uuid: $0, name: "tag_\($0)", colorHex: "hex")
        }
    }
    
    var shouldFailLoadAllTags: Bool = false
    func loadAllTags() async throws -> [CustomEventTag] {
        guard shouldFailLoadAllTags == false
        else {
            throw RuntimeError("failed")
        }
        return [
            .init(uuid: "t1", name: "cached1", colorHex: "hex"),
            .init(uuid: "t2", name: "cached1", colorHex: "hex"),
            .init(uuid: "t3", name: "cached1", colorHex: "hex")
        ]
    }
    
    var didRemoveAll: Bool?
    func removeAllTags() async throws {
        self.didRemoveAll = true
    }
}
