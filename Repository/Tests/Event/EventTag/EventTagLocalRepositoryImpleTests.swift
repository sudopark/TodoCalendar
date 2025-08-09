//
//  EventTagLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/05/28.
//

import XCTest
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


class EventTagLocalRepositoryImpleTests: BaseLocalTests {
    
    var localStorage: EventTagLocalStorageImple!
    var todoLocalStorage: TodoLocalStorageImple!
    var scheduleLocalStorage: ScheduleEventLocalStorageImple!
    var fakeEnvStore: FakeEnvironmentStorage!
    
    override func setUpWithError() throws {
        self.fileName = "tags"
        try super.setUpWithError()
        self.localStorage = .init(sqliteService: self.sqliteService)
        self.todoLocalStorage = .init(sqliteService: self.sqliteService)
        self.scheduleLocalStorage = .init(sqliteService: self.sqliteService)
        self.sqliteService.run { db in
            try db.createTableOrNot(CustomEventTagTable.self)
        }
        self.fakeEnvStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.localStorage = nil
        self.fakeEnvStore = nil
        try super.tearDownWithError()
    }
    
    func makeRepository() -> any EventTagRepository {
        return EventTagLocalRepositoryImple(
            localStorage: self.localStorage,
            todoLocalStorage: self.todoLocalStorage,
            scheduleLocalStorage: self.scheduleLocalStorage,
            environmentStorage: self.fakeEnvStore
        )
    }
}


extension EventTagLocalRepositoryImpleTests {
    
    // make
    func testRepository_makeNewTag() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = CustomEventTagMakeParams(name: "some", colorHex: "hex")
        let result = try? await repository.makeNewTag(params)
        
        // then
        XCTAssertEqual(result?.name, "some")
        XCTAssertEqual(result?.colorHex, "hex")
    }
    
    // make and same name exists -> error
    func testRepository_whenMakeNewTag_sameNameExists_error() async {
        // given
        let repository = self.makeRepository()
        let params = CustomEventTagEditParams(name: "some", colorHex: "hex")
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
        let params = CustomEventTagMakeParams(name: "old name", colorHex: "hex")
        let origin = try? await repository.makeNewTag(params)
        
        // when
        let editParams = CustomEventTagEditParams(name: "new name", colorHex: "new hex")
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
        let params = CustomEventTagMakeParams(name: "same name", colorHex: "hex")
        let _ = try? await repository.makeNewTag(params)
        let params2 = CustomEventTagMakeParams(name: "not same name", colorHex: "hex2")
        let origin = try? await repository.makeNewTag(params2)
        
        // when
        let editParams = CustomEventTagEditParams(name: "same name", colorHex: "hex")
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
        let params = CustomEventTagMakeParams(name: "origin", colorHex: "hex")
        let origin = try? await repository.makeNewTag(params)
        
        // when
        let editParams = CustomEventTagEditParams(name: "origin", colorHex: "new hex")
        let result = try? await repository.editTag(origin?.uuid ?? "", editParams)
        
        // then
        XCTAssertEqual(result?.uuid, origin?.uuid)
        XCTAssertEqual(result?.name, "origin")
        XCTAssertEqual(result?.colorHex, "new hex")
    }
    
    func testRepository_whenDeleteTag_removeFromTagAndOffIds() async throws {
        // given
        let repository = self.makeRepository()
        let params = CustomEventTagMakeParams(name: "some", colorHex: "hex")
        let origin = try await repository.makeNewTag(params)
        let _ = repository.toggleTagIsOn(.custom(origin.uuid))
        
        // when
        try await repository.deleteTag(origin.uuid)
        let tagAfterDelete = try await repository.loadCustomTags([origin.uuid]).firstValue(with: 100)
        let offIdsAfterDelete = repository.loadOffTags()
        
        // then
        XCTAssertEqual(tagAfterDelete?.count, 0)
        XCTAssertEqual(offIdsAfterDelete, [])
    }
    
    func testRepository_resetExternalCalendarOffTagIds() {
        // given
        let repository = self.makeRepository()
        let customTags = (0..<10).map { EventTagId.custom("id:\($0)") }
        let externalTags = (0..<10).map { EventTagId.externalCalendar(serviceId: "google", id: "id:\($0)")}
        (customTags + externalTags).forEach { id in
            _ = repository.toggleTagIsOn(id)
        }
        
        // when
        repository.resetExternalCalendarOffTagId("google")
        let ids = repository.loadOffTags()
        
        // then
        XCTAssertEqual(ids, Set(customTags))
    }
    
    func stubTodoAndSchedule() async throws {
        func makeTodo(_ id: Int, with tag: String) -> TodoEvent {
            return TodoEvent.dummy(id)
                |> \.eventTagId .~ .custom(tag)
                |> \.time .~ .at(100)
        }
        func makeSchedule(_ id: Int, with tag: String) -> ScheduleEvent {
            return ScheduleEvent(uuid: "sc:\(id)", name: "some", time: .at(100))
                |> \.eventTagId .~ .custom(tag)
        }
        let todoWithTag1 = (0..<3).map { makeTodo($0, with: "t1") }
        let todoWithTag2 = (3..<7).map { makeTodo($0, with: "t2") }
        let scheduleWithTag1 = (0..<3).map { makeSchedule($0, with: "t1") }
        let scheduleWithTag2 = (3..<7).map { makeSchedule($0, with: "t2") }
        try await self.todoLocalStorage.updateTodoEvents(todoWithTag1 + todoWithTag2)
        try await self.scheduleLocalStorage.updateScheduleEvents(scheduleWithTag1 + scheduleWithTag2)
        
        let tag1 = CustomEventTag(uuid: "t1", name: "t1", colorHex: "some")
        let tag2 = CustomEventTag(uuid: "t2", name: "t2", colorHex: "some")
        try await self.localStorage.updateTags([tag1, tag2])
    }
    
    func testRepository_deleteTagWithEvents() async throws {
        // given
        try await self.stubTodoAndSchedule()
        let repository = self.makeRepository()
        
        // when
        let result = try await repository.deleteTagWithAllEvents("t1")
        
        // then
        XCTAssertEqual(result.todoIds, (0..<3).map { "id:\($0)" })
        XCTAssertEqual(result.scheduleIds, (0..<3).map { "sc:\($0)" })
        let allTodos = try await self.todoLocalStorage.loadAllEvents()
        let allSchedules = try await self.scheduleLocalStorage.loadAllEvents()
        XCTAssertEqual(allTodos.map { $0.uuid }, (3..<7).map { "id:\($0)" })
        XCTAssertEqual(allSchedules.map { $0.uuid }, (3..<7).map { "sc:\($0)" })
    }
}

extension EventTagLocalRepositoryImpleTests {
    
    
    // load tags
    private func makeRepositoryWithStubSaveTags(_ tags: [CustomEventTag]) async throws -> any EventTagRepository {
        try await self.localStorage.updateTags(tags)
        return self.makeRepository()
    }
    
    func testRepository_loadTagsByIds() async throws {
        // given
        let totalIds = (0..<10).map { "\($0)" }
        let stubTags = totalIds.map { CustomEventTag(uuid: $0, name: "name:\($0)", colorHex: "hex:\($0)")}
        let repository = try await self.makeRepositoryWithStubSaveTags(stubTags)
        
        // when
        let someIds = (0..<10).filter { $0 % 2 == 0 }.map { "\($0)" }
        let tags = try await repository.loadCustomTags(someIds).values.first(where: { _ in true })
        
        // then
        let ids = tags?.map { $0.uuid }
        XCTAssertEqual(ids, someIds)
    }
    
    func testRepository_loadAllTags() async throws {
        // given
        let totalTags = (0..<100).map { int -> CustomEventTag in
            return .init(uuid: "id:\(int)", name: "some:\(int)", colorHex: "some")
        }
        let repository = try await self.makeRepositoryWithStubSaveTags(totalTags)
        
        // when
        let tags = try await repository.loadAllCustomTags().firstValue(with: 10)
        
        // then
        XCTAssertEqual(tags?.map { $0.uuid }, totalTags.map { $0.uuid })
    }
}

extension EventTagLocalRepositoryImpleTests {
    
    func testRepository_toggleAndLoadOffIds() {
        // given
        let repository = self.makeRepository()
        
        // when + then
        var ids = repository.loadOffTags()
        XCTAssertEqual(ids, [])
        ids = repository.toggleTagIsOn(.custom("t1"))
        XCTAssertEqual(ids, [.custom("t1")])
        ids = repository.toggleTagIsOn(.custom("t2"))
        XCTAssertEqual(ids, [.custom("t1"), .custom("t2")])
        ids = repository.toggleTagIsOn(.custom("t1"))
        XCTAssertEqual(ids, [.custom("t2")])
        ids = repository.toggleTagIsOn(.holiday)
        XCTAssertEqual(ids, [.custom("t2"), .holiday])
    }
}
