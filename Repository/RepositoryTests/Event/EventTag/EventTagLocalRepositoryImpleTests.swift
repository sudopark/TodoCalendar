//
//  EventTagLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/05/28.
//

import XCTest
import Combine
import AsyncFlatMap
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


class EventTagLocalRepositoryImpleTests: BaseLocalTests {
    
    private var localStorage: EventTagLocalStorage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.localStorage = .init(sqliteService: self.sqliteService)
        self.sqliteService.run { db in
            try db.createTableOrNot(EventTagTable.self)
        }
    }
    
    override func tearDownWithError() throws {
        self.localStorage = nil
        try super.tearDownWithError()
    }
    
    private func makeRepository() -> EventTagLocalRepositoryImple {
        return .init(localStorage: self.localStorage)
    }
}


extension EventTagLocalRepositoryImpleTests {
    
    // make
    func testRepository_makeNewTag() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = EventTagMakeParams(name: "some", colorHex: "hex")
        let result = try? await repository.makeNewTag(params)
        
        // then
        XCTAssertEqual(result?.name, "some")
        XCTAssertEqual(result?.colorHex, "hex")
    }
    
    // make and same name exists -> error
    func testRepository_whenMakeNewTag_sameNameExists_error() async {
        // given
        let repository = self.makeRepository()
        let params = EventTagEditParams(name: "some", colorHex: "hex")
        let _ = try? await repository.makeNewTag(params)
        
        // when
        var failedReason: RuntimeError?
        do {
            let _ = try await repository.makeNewTag(params)
        } catch {
            failedReason = error as? RuntimeError
        }
        
        // then
        XCTAssertEqual(failedReason?.key, "EvnetTag_Name_Duplicated")
    }
    
    // update
    func testRepository_editTag() async {
        // given
        let repository = self.makeRepository()
        let params = EventTagMakeParams(name: "old name", colorHex: "hex")
        let origin = try? await repository.makeNewTag(params)
        
        // when
        let editParams = EventTagEditParams(name: "new name", colorHex: "new hex")
        let newOne = try? await repository.editTag(origin?.uuid ?? "", editParams)
        
        // then
        XCTAssertEqual(newOne?.uuid, origin?.uuid)
        XCTAssertEqual(newOne?.name, "new name")
        XCTAssertEqual(newOne?.colorHex, "new hex")
    }
    
    // update and same name exits -> error
    func testRepository_whenEditTagAndSameNameExists_error() async {
        // given
        let repository = self.makeRepository()
        let params = EventTagMakeParams(name: "same name", colorHex: "hex")
        let _ = try? await repository.makeNewTag(params)
        let params2 = EventTagMakeParams(name: "not same name", colorHex: "hex2")
        let origin = try? await repository.makeNewTag(params2)
        
        // when
        let editParams = EventTagEditParams(name: "same name", colorHex: "hex")
        var failReason: RuntimeError?
        do {
            let _ = try await repository.editTag(origin?.uuid ?? "", editParams)
        } catch {
            failReason = error as? RuntimeError
        }
        
        // then
        XCTAssertEqual(failReason?.key, "EvnetTag_Name_Duplicated")
    }
    
    func testRepository_editOnlyhex() async {
        // given
        let repository = self.makeRepository()
        let params = EventTagMakeParams(name: "origin", colorHex: "hex")
        let origin = try? await repository.makeNewTag(params)
        
        // when
        let editParams = EventTagEditParams(name: "origin", colorHex: "new hex")
        let result = try? await repository.editTag(origin?.uuid ?? "", editParams)
        
        // then
        XCTAssertEqual(result?.uuid, origin?.uuid)
        XCTAssertEqual(result?.name, "origin")
        XCTAssertEqual(result?.colorHex, "new hex")
    }
}

extension EventTagLocalRepositoryImpleTests {
    
    // load tags
    private func makeRepositoryWithStubSaveTags(_ ids: [String]) async throws -> EventTagLocalRepositoryImple {
        let tags = ids.map { EventTag(uuid: $0, name: "name:\($0)", colorHex: "hex:\($0)")}
        try await self.localStorage.updateTags(tags)
        return self.makeRepository()
    }
    
    func testRepository_loadTagsByIds() async throws {
        // given
        let totalIds = (0..<10).map { "\($0)" }
        let repository = try await self.makeRepositoryWithStubSaveTags(totalIds)
        
        // when
        let someIds = (0..<10).filter { $0 % 2 == 0 }.map { "\($0)" }
        let tags = try await repository.loadTags(someIds).values.first(where: { _ in true })
        
        // then
        let ids = tags?.map { $0.uuid }
        XCTAssertEqual(ids, someIds)
    }
}