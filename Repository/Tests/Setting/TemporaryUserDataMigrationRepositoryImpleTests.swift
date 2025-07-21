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
import SQLiteService
import Domain
import UnitTestHelpKit

@testable import Repository


class TemporaryUserDataMigrationRepositoryImpleTests: BaseLocalTests {
    
    private var stubRemote: StubRemoteAPI!
    private var eventTagLocalStorage: EventTagLocalStorageImple!
    private var todoLocalStorage: TodoLocalStorageImple!
    private var scheduleLocalStorage: ScheduleEventLocalStorageImple!
    private var eventDetailLocalStorage: EventDetailDataLocalStorageImple!
    private var syncTimeLocalStorage: EventSyncTimestampLocalStorageImple!
    private let tempDBPath: String = "temp"
    
    override func setUpWithError() throws {
        self.fileName = "user_db"
        try super.setUpWithError()
        self.stubRemote = .init(responses: self.responses)
        self.eventTagLocalStorage = .init(sqliteService: self.sqliteService)
        self.todoLocalStorage = .init(sqliteService: self.sqliteService)
        self.scheduleLocalStorage = .init(sqliteService: self.sqliteService)
        self.eventDetailLocalStorage = .init(sqliteService: self.sqliteService)
        self.syncTimeLocalStorage = EventSyncTimestampLocalStorageImple(sqliteService: self.sqliteService)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.stubRemote = nil
        self.syncTimeLocalStorage = nil
    }
    
    private var dummyTime: EventTime {
        return .period(0..<100)
    }
    
    private var dummyRepeating: EventRepeating {
        return EventRepeating(
            repeatingStartTime: 100,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        |> \.repeatingEndOption .~ .until(1000)
    }
    
    private var dummyNotificationOptions: [EventNotificationTimeOption] {
        return [
            .atTime, .allDay12AM
        ]
    }
    
    private func prepareDummyData() async throws {
        let tempDBService = SQLiteService()
        _ = tempDBService.open(path: self.tempDBPath)
        defer { tempDBService.close() }
        let tags = [
            CustomEventTag(uuid: "t1", name: "n1", colorHex: "some"),
            CustomEventTag(uuid: "t2", name: "n2", colorHex: "some"),
        ]
        let tagStorage = EventTagLocalStorageImple(sqliteService: tempDBService)
        try await tagStorage.updateTags(tags)
        
        let todo1 = TodoEvent(uuid: "todo1", name: "todo1")
            |> \.eventTagId .~ .custom("t1")
            |> \.time .~ pure(self.dummyTime)
            |> \.repeating .~ pure(self.dummyRepeating)
            |> \.notificationOptions .~ self.dummyNotificationOptions
            |> \.creatTimeStamp .~ 100
        
        let todo2 = TodoEvent(uuid: "todo2", name: "todo2")
            |> \.eventTagId .~ .custom("t2")
            |> \.creatTimeStamp .~ 200
        let todoStorage = TodoLocalStorageImple(sqliteService: tempDBService)
        try await todoStorage.updateTodoEvents([todo1, todo2])
        
        let done1 = DoneTodoEvent(uuid: "d1", name: "d1", originEventId: "todo1", doneTime: Date())
        |> \.eventTime .~ self.dummyTime
        
        let done2 = DoneTodoEvent(uuid: "d2", name: "d2", originEventId: "todo2", doneTime: Date())
        |> \.eventTime .~ self.dummyTime
        |> \.notificationOptions .~ self.dummyNotificationOptions
        try await todoStorage.saveDoneTodoEvent(done1)
        try await todoStorage.saveDoneTodoEvent(done2)
        
        let sc1 = ScheduleEvent(uuid: "sc1", name: "sc1", time: self.dummyTime)
            |> \.repeating .~ self.dummyRepeating
            |> \.showTurn .~ true
            |> \.repeatingTimeToExcludes .~ ["some"]
        let sc2 = ScheduleEvent(uuid: "sc2", name: "sc2", time: self.dummyTime)
        let scheduleStorage = ScheduleEventLocalStorageImple(sqliteService: tempDBService)
        try await scheduleStorage.updateScheduleEvents([sc1, sc2])
        
        let detail1 = EventDetailData("todo1")
            |> \.memo .~ "memo"
            |> \.place .~ .init("place", .init(200, 300))
        let detailStorage = EventDetailDataLocalStorageImple(sqliteService: tempDBService)
        try await detailStorage.saveDetail(detail1)
    }
    
    private func makeRepository(withoutData: Bool = false) async throws -> TemporaryUserDataMigrationRepositoryImple {
        let repository = TemporaryUserDataMigrationRepositoryImple(
            tempUserDBPath: self.tempDBPath,
            remoteAPI: self.stubRemote,
            eventTagLocalStorage: self.eventTagLocalStorage,
            todoLocalStorage: self.todoLocalStorage,
            scheduleLocalStorage: self.scheduleLocalStorage,
            eventDetailLocalStorage: self.eventDetailLocalStorage,
            syncTimeLocalStorage: self.syncTimeLocalStorage
        )
        if !withoutData {
            try await self.prepareDummyData()
        } else {
            let service = SQLiteService()
            _ = service.open(path: self.tempDBPath)
            service.close()
        }
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
        
        let timestamp = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .eventTag)
        XCTAssertEqual(timestamp, .init(.eventTag, 100))
        
        let tagsInUserDB = try await self.eventTagLocalStorage.loadAllTags()
        let ids = tagsInUserDB.map { $0.uuid }
        XCTAssertEqual(ids, ["t1", "t2"])
    }
    
    func testRepository_migrationTodoEvents() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateTodoEvents()
        
        // then
        let batchTodoIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        let createTimestamps = self.stubRemote.didRequestedParams?.compactMapValues { payload -> TimeInterval? in
            return (payload as? [String: Any])?["create_timestamp"] as? TimeInterval
        }
        XCTAssertEqual(batchTodoIds, ["todo1", "todo2"])
        XCTAssertEqual(createTimestamps, [
            "todo1": 100, "todo2": 200
        ])
        
        let timestamp = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .todo)
        XCTAssertEqual(timestamp, .init(.todo, 101))
        
        let todosInUserDB = try await self.todoLocalStorage.loadAllEvents()
        let ids = todosInUserDB.map { $0.uuid }
        XCTAssertEqual(ids, ["todo1", "todo2"])
    }
    
    func testRepository_migrationScheduleEvents() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateScheduleEvents()
        
        // then
        let batchScheduleEventIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        XCTAssertEqual(batchScheduleEventIds, ["sc1", "sc2"])
        
        let timestamp = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .schedule)
        XCTAssertEqual(timestamp, .init(.schedule, 102))
        
        let schedulesInUserDB = try await self.scheduleLocalStorage.loadAllEvents()
        let ids = schedulesInUserDB.map { $0.uuid }
        XCTAssertEqual(ids, ["sc1", "sc2"])
    }
    
    func testRepository_migrationEventDetails() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateEventDetails()
        
        // then
        let detailEventIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        XCTAssertEqual(detailEventIds, ["todo1"])
        
        let detailsInUserDB = try await self.eventDetailLocalStorage.loadAll()
        let ids = detailsInUserDB.map { $0.eventId }
        XCTAssertEqual(ids, ["todo1"])
    }
    
    func testRespository_migrateDoneTodoEvents() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateDoneEvents()
        
        // then
        let doneIds = self.stubRemote.didRequestedParams?.keys.sorted().map { $0 }
        XCTAssertEqual(doneIds, ["d1", "d2"])
        
        let doneTodosInUserBD = try await self.todoLocalStorage.loadAllDoneEvents()
        let ids = doneTodosInUserBD.map { $0.uuid }
        XCTAssertEqual(ids, ["d1", "d2"])
    }
    
    func testReposiotry_clearTempUserData() async throws {
        // given
        let repository = try await self.makeRepository()
        XCTAssertEqual(FileManager.default.fileExists(atPath: self.tempDBPath), true)
        
        // when
        try await repository.clearTemporaryUserData()
        
        // then
        XCTAssertEqual(FileManager.default.fileExists(atPath: self.tempDBPath), false)
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
        
        let timestampTag = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .eventTag)
        XCTAssertEqual(timestampTag, .init(.eventTag, 100))
        let timestampTodo = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .todo)
        XCTAssertEqual(timestampTodo, .init(.todo, 101))
        let timestampSchedule = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .schedule)
        XCTAssertEqual(timestampSchedule, .init(.schedule, 102))
    }
    
    func testReposiotry_whenMigrateTargetDataIsEmpty_notUpload() async throws {
        // given
        let repository = try await self.makeRepository(withoutData: true)
        
        // when
        try await repository.migrateEventTags()
        try await repository.migrateTodoEvents()
        try await repository.migrateScheduleEvents()
        try await repository.migrateEventDetails()
        
        // then
        XCTAssertEqual(self.stubRemote.didRequestedPaths.isEmpty, true)
        
        let timestampTag = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .eventTag)
        XCTAssertNil(timestampTag)
        let timestampTodo = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .todo)
        XCTAssertNil(timestampTodo)
        let timestampSchedule = try await self.syncTimeLocalStorage.loadLocalTimestamp(for: .schedule)
        XCTAssertNil(timestampSchedule)
    }
}

extension TemporaryUserDataMigrationRepositoryImpleTests {
    
    private var okReponse: String {
        return """
        { "status": "ok" }
        """
    }
    
    private func okResponse(with timestamp: Int) -> String {
        return """
        { "status": "ok", "syncTimestamp": \(timestamp) }
        """
    }
    
    private var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .post,
                endpoint: MigrationEndpoints.eventTags,
                resultJsonString: .success(self.okResponse(with: 100))
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.todos,
                resultJsonString: .success(self.okResponse(with: 101))
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.schedules,
                resultJsonString: .success(self.okResponse(with: 102))
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.eventDetails,
                resultJsonString: .success(self.okReponse)
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.doneTodos,
                resultJsonString: .success(self.okReponse)
            )
        ]
    }
}
