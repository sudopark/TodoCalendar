//
//  EventTagUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/05/27.
//

import XCTest
import Combine
import Extensions
import AsyncFlatMap
import UnitTestHelpKit

@testable import Domain


class EventTagUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRepository: StubEventTagRepository!
    private var sharedDataStore: SharedDataStore!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
        self.sharedDataStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
        self.sharedDataStore = nil
    }
    
    private func makeUsecase() -> EventTagUsecaseImple {
        return EventTagUsecaseImple(
            tagRepository: self.stubRepository,
            sharedDataStore: self.sharedDataStore
        )
    }
    
    private func stubMakeFail() {
        self.stubRepository.makeFailError = RuntimeError("duplicate name")
    }
    
    private func stubUpdateFail() {
        self.stubRepository.updateFailError = RuntimeError("duplicate name")
    }
}


extension EventTagUsecaseImpleTests {
    
    // make new
    func testUsecase_makeNewTag() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EventTagMakeParams(name: "new", colorHex: "hex")
        let new = try? await usecase.makeNewTag(params)
        
        // then
        XCTAssertEqual(new?.name, "new")
        XCTAssertEqual(new?.colorHex, "hex")
    }
    
    // make new error
    func testUsecase_makeNewTagFail() async {
        // given
        let usecase = self.makeUsecase()
        self.stubMakeFail()
        
        // when
        let params = EventTagMakeParams(name: "new", colorHex: "hex")
        let new = try? await usecase.makeNewTag(params)
        
        // then
        XCTAssertNil(new)
    }
    
    // update new
    func testUsecase_updateTag() async {
        // given
        let usecase = self.makeUsecase()
        let makeParams = EventTagMakeParams(name: "origin", colorHex: "hex")
        let origin = try? await usecase.makeNewTag(makeParams)
        
        // when
        let updateParams = EventTagEditParams(name: "new name", colorHex: "new hex")
        let new = try? await usecase.editTag(origin?.uuid ?? "", updateParams)
        
        // then
        XCTAssertEqual(new?.uuid, origin?.uuid)
        XCTAssertEqual(new?.name, "new name")
        XCTAssertEqual(new?.colorHex, "new hex")
    }
    
    // update new error
    func testUsecase_updateTagFail() async {
        // given
        let usecase = self.makeUsecase()
        self.stubUpdateFail()
        let makeParams = EventTagMakeParams(name: "origin", colorHex: "hex")
        let origin = try? await usecase.makeNewTag(makeParams)
        
        // when
        let updateParams = EventTagEditParams(name: "new name", colorHex: "new hex")
        let new = try? await usecase.editTag(origin?.uuid ?? "", updateParams)
        
        // then
        XCTAssertNil(new)
    }
}

extension EventTagUsecaseImpleTests {
    
    // load tags in ids
    func testUsecase_loadEventTagsByIds() {
        // given
        let expect = expectation(description: "ids에 해당하는 event tag 조회")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let ids = (0..<10).map { "id:\($0)"}
        let tagSource = usecase.eventTags(ids)
        let tagMaps = self.waitOutputs(expect, for: tagSource) {
            usecase.refreshTags(ids)
        }
        
        // then
        let tagMapKeys = tagMaps.map { $0.keys.map { $0 }.sorted() }
        XCTAssertEqual(tagMapKeys, [
            [],
            ids
        ])
    }
    
    private func stubMakeTag(_ usecase: EventTagUsecase) -> EventTag {
        let expect = expectation(description: "tag 생성 조회")
        
        let making: AsyncFlatMapPublisher<Void, Error, EventTag> = Publishers.create {
            try await usecase.makeNewTag(.init(name: "origin", colorHex: "hex"))
        }
        
        let new = self.waitFirstOutput(expect, for: making)
        return new!
    }
    
    // load tags in ids + update one
    func testUsecase_whenAfterUpdate_updateTagsInIds() {
        // given
        let usecase = self.makeUsecase()
        let origin = self.stubMakeTag(usecase)
        let expect = expectation(description: "id에 해당하는 tag 업데이트시 조회중인 tag 업데이트")
        expect.expectedFulfillmentCount = 2
        
        // when
        let ids = [origin.uuid]
        let tagSource = usecase.eventTags(ids)
        let tagMaps = self.waitOutputs(expect, for: tagSource) {
            Task {
                let params = EventTagEditParams(name: "new name", colorHex: "hex")
                _ = try await usecase.editTag(origin.uuid, params)
            }
        }
        
        // then
        let loadedOrigin = tagMaps.first?[origin.uuid]
        let loadedUpdated = tagMaps.last?[origin.uuid]
        XCTAssertEqual(tagMaps.count, 2)
        XCTAssertEqual(loadedOrigin?.name, "origin")
        XCTAssertEqual(loadedUpdated?.name, "new name")
    }
}
