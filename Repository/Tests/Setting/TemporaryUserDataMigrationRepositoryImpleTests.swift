//
//  TemporaryUserDataMigrationRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit

@testable import Repository


class TemporaryUserDataMigrationRepositoryImpleTests: BaseLocalTests {
    
    private var stubRemote: StubRemoteAPI!
    
    override func setUpWithError() throws {
        self.fileName = "temps"
        try super.setUpWithError()
        self.stubRemote = .init(responses: self.responses)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.stubRemote = nil
    }
    
    private var dummyTime: EventTime {
        return .period(0..<100)
    }
    
    private var dummyRepeating: EventRepeating {
        return EventRepeating(
            repeatingStartTime: 100,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        |> \.repeatingEndTime .~ 1000
    }
    
    private var dummyNotificationOptions: [EventNotificationTimeOption] {
        return [
            .atTime, .allDay12AM
        ]
    }
    
    private func prepareDummyData() async throws {
        defer { self.sqliteService.close() }
        let tags = [
            EventTag(uuid: "t1", name: "n1", colorHex: "some"),
            EventTag(uuid: "t2", name: "n2", colorHex: "some"),
        ]
        let tagStorage = EventTagLocalStorageImple(sqliteService: self.sqliteService)
        try await tagStorage.updateTags(tags)
        
        let todo1 = TodoEvent(uuid: "todo1", name: "todo1")
            |> \.eventTagId .~ .custom("t1")
            |> \.time .~ pure(self.dummyTime)
            |> \.repeating .~ pure(self.dummyRepeating)
            |> \.notificationOptions .~ self.dummyNotificationOptions
        
        let todo2 = TodoEvent(uuid: "todo2", name: "todo2")
            |> \.eventTagId .~ .custom("t2")
        let todoStorage = TodoLocalStorageImple(sqliteService: self.sqliteService)
        try await todoStorage.updateTodoEvents([todo1, todo2])
        
        let sc1 = ScheduleEvent(uuid: "sc1", name: "sc1", time: self.dummyTime)
            |> \.repeating .~ self.dummyRepeating
            |> \.showTurn .~ true
            |> \.repeatingTimeToExcludes .~ ["some"]
        let sc2 = ScheduleEvent(uuid: "sc2", name: "sc2", time: self.dummyTime)
        let scheduleStorage = ScheduleEventLocalStorageImple(sqliteService: self.sqliteService)
        try await scheduleStorage.updateScheduleEvents([sc1, sc2])
        
        let detail1 = EventDetailData("todo1")
            |> \.memo .~ "memo"
            |> \.place .~ .init("place", .init(200, 300))
        let detailStorage = EventDetailDataLocalStorageImple(sqliteService: self.sqliteService)
        try await detailStorage.saveDetail(detail1)
    }
    
    private func makeRepository() async throws -> TemporaryUserDataMigrationRepositoryImple {
        let repository = TemporaryUserDataMigrationRepositoryImple(
            tempUserDBPath: self.testDBPath(),
            remoteAPI: self.stubRemote
        )
        try await self.prepareDummyData()
        return repository
    }
}

extension TemporaryUserDataMigrationRepositoryImpleTests {
    
    func testRepository_loadEventCount() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        let count = try await repository.loadMigrationNeedEventCount()
        
        // then
        XCTAssertEqual(count, 4)
    }
    
    func testRepository_migrationEventTag() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateEventTags()
        
        // then
        let batchTagIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        XCTAssertEqual(batchTagIds, ["t1", "t2"])
    }
    
    func testRepository_migrationTodoEvents() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateTodoEvents()
        
        // then
        let batchTodoIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        XCTAssertEqual(batchTodoIds, ["todo1", "todo2"])
    }
    
    func testRepository_migrationScheduleEvents() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateScheduleEvents()
        
        // then
        let batchScheduleEventIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        XCTAssertEqual(batchScheduleEventIds, ["sc1", "sc2"])
    }
    
    func testRepository_migrationEventDetails() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateEventDetails()
        
        // then
        let detailEventIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        XCTAssertEqual(detailEventIds, ["todo1"])
    }
    
    func testReposiotry_clearTempUserData() async throws {
        // given
        let repository = try await self.makeRepository()
        XCTAssertEqual(FileManager.default.fileExists(atPath: self.testDBPath()), true)
        
        // when
        try await repository.clearTemporaryUserData()
        
        // then
        XCTAssertEqual(FileManager.default.fileExists(atPath: self.testDBPath()), false)
    }
    
    func testRepository_migrate() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        let countBeforeMigration = try await repository.loadMigrationNeedEventCount()
        try await repository.migrateEventTags()
        try await repository.migrateTodoEvents()
        try await repository.migrateScheduleEvents()
        try await repository.migrateEventDetails()
        try await repository.clearTemporaryUserData()
        let countAfterMigration = try? await repository.loadMigrationNeedEventCount()
        
        // then
        XCTAssertEqual(countBeforeMigration, 4)
        XCTAssertEqual(countAfterMigration, nil)
    }
}

extension TemporaryUserDataMigrationRepositoryImpleTests {
    
    private var okReponse: String {
        return """
        { "status": "ok" }
        """
    }
    
    private var responses: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                method: .post,
                endpoint: MigrationEndpoints.eventTags,
                resultJsonString: .success(self.okReponse)
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.todos,
                resultJsonString: .success(self.okReponse)
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.schedules,
                resultJsonString: .success(self.okReponse)
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.eventDetails,
                resultJsonString: .success(self.okReponse)
            ),
        ]
    }
}