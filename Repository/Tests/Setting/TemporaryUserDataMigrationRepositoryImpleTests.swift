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
import Extensions
import SQLiteService
import UnitTestHelpKit

@testable import Repository


class TemporaryUserDataMigrationRepositoryImpleTests: BaseLocalTests {
    
    private var stubRemote: StubRemoteAPI!
    private var accountSqliteService: SQLiteService!
    private var accountDBPath: String!
    
    override func setUpWithError() throws {
        self.fileName = "temps"
        try super.setUpWithError()
        self.stubRemote = .init(responses: self.responses)
        self.accountDBPath = try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("temps_account_\(UUID().uuidString).db")
            .path
        self.accountSqliteService = SQLiteService()
        _ = self.accountSqliteService.open(path: self.accountDBPath)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.stubRemote = nil
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        let path = self.accountDBPath
        let service = self.accountSqliteService
        self.accountDBPath = nil
        self.accountSqliteService = nil
        
        guard let path, let service else { return }
        // 열린 커넥션이 물고 있는 vnode 를 unlink 하면 sqlite 가 프로세스를 죽인다
        guard (try? await service.async.close()) != nil else { return }
        try? FileManager.default.removeItem(atPath: path)
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
        // 시드 커넥션은 repo 가 같은 파일을 열기 전에 닫는다 — 닫은 뒤엔 tearDown 이 지울 파일만 남는다
        defer {
            self.sqliteService.close()
            self.sqliteService = nil
        }
        let tags = [
            CustomEventTag(uuid: "t1", name: "n1", colorHex: "some"),
            CustomEventTag(uuid: "t2", name: "n2", colorHex: "some"),
        ]
        let tagStorage = EventTagLocalStorageImple(
            sqliteService: self.sqliteService, environmentStorage: FakeEnvironmentStorage()
        )
        try await tagStorage.updateTags(tags)
        
        let todo1 = TodoEvent(uuid: "todo1", name: "todo1")
            |> \.eventTagId .~ .custom("t1")
            |> \.time .~ pure(self.dummyTime)
            |> \.repeating .~ pure(self.dummyRepeating)
            |> \.notificationOptions .~ self.dummyNotificationOptions
            |> \.creatTimeStamp .~ 100
            |> \.repeatingTurn .~ 4

        let todo2 = TodoEvent(uuid: "todo2", name: "todo2")
            |> \.eventTagId .~ .custom("t2")
            |> \.creatTimeStamp .~ 200
        let todoStorage = TodoLocalStorageImple(sqliteService: self.sqliteService)
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
        let scheduleStorage = ScheduleEventLocalStorageImple(sqliteService: self.sqliteService)
        try await scheduleStorage.updateScheduleEvents([sc1, sc2])
        
        let detail1 = EventDetailData("todo1")
            |> \.memo .~ "memo"
            |> \.place .~ .init("place", .init(200, 300))
        let detailStorage = EventDetailDataLocalStorageImple<EventDetailDataTable>(sqliteService: self.sqliteService)
        try await detailStorage.saveDetail(detail1)
        
        let doneTodoDetail1 = EventDetailData(done1.uuid)
        let doneTodoDetailStorage = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(sqliteService: self.sqliteService)
        try await doneTodoDetailStorage.saveDetail(doneTodoDetail1)

        let themeStorage = CustomColorThemeLocalStorageImple(sqliteService: self.sqliteService)
        try await themeStorage.saveTheme(self.makeTheme("ct1", name: "theme1", createdAt: 100.7))
        try await themeStorage.saveTheme(self.makeTheme("ct2", name: "theme2", createdAt: 200))
    }

    private func makeTheme(_ uuid: String, name: String, createdAt: TimeInterval) -> CustomColorTheme {
        return CustomColorTheme(
            uuid: uuid,
            name: name,
            schemaVersion: 1,
            seeds: CustomColorThemeSeeds(background: "#000000", accent: "#FFFFFF", form: .filled),
            colors: ["bg0": "#000000"],
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
    
    private func makeRepository(withoutData: Bool = false) async throws -> TemporaryUserDataMigrationRepositoryImple {
        let repository = TemporaryUserDataMigrationRepositoryImple(
            tempUserDBPath: self.testDBPath(),
            remoteAPI: self.stubRemote,
            environmentStorage: FakeEnvironmentStorage(),
            accountSqliteService: self.accountSqliteService
        )
        if !withoutData {
            try await self.prepareDummyData()
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
        XCTAssertEqual(count, 6)
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
        let createTimestamps = self.stubRemote.didRequestedParams?.compactMapValues { payload -> TimeInterval? in
            return (payload as? [String: Any])?["create_timestamp"] as? TimeInterval
        }
        XCTAssertEqual(batchTodoIds, ["todo1", "todo2"])
        XCTAssertEqual(createTimestamps, [
            "todo1": 100, "todo2": 200
        ])
    }

    // 반복 할일 이관시 회차도 함께 전송
    func testRepository_whenMigrateRepeatingTodo_uploadRepeatingTurn() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateTodoEvents()

        // then
        let todo1Payload = self.stubRemote.didRequestedParams?["todo1"] as? [String: Any]
        XCTAssertEqual(todo1Payload?["repeating_turn"] as? Int, 4)
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
    
    func testRespository_migrateDoneTodoEvents() async throws {
        // given
        let repository = try await self.makeRepository()
        
        // when
        try await repository.migrateDoneEvents()
        
        // then
        let paths = self.stubRemote.didRequestedPaths
        XCTAssertEqual(paths, [
            "dummy_calendar_api_host/v2/migration/todos/done",
            "dummy_calendar_api_host/v2/migration/todos/done/details"
        ])
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
        try await repository.migrateCustomColorThemes()
        try await repository.clearTemporaryUserData()
        let countAfterMigration = try? await repository.loadMigrationNeedEventCount()
        
        // then
        XCTAssertEqual(countBeforeMigration, 6)
        XCTAssertEqual(countAfterMigration, nil)
    }
    
    func testReposiotry_whenMigrateTargetDataIsEmpty_notUpload() async throws {
        // given
        let repository = try await self.makeRepository(withoutData: true)
        
        // when
        try await repository.migrateEventTags()
        try await repository.migrateTodoEvents()
        try await repository.migrateScheduleEvents()
        try await repository.migrateEventDetails()
        try await repository.migrateCustomColorThemes()
        
        // then
        XCTAssertEqual(self.stubRemote.didRequestedPaths.isEmpty, true)
    }
}

extension TemporaryUserDataMigrationRepositoryImpleTests {

    func testRepository_migrateCustomColorThemes_uploadUuidKeyedBatch() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateCustomColorThemes()

        // then
        XCTAssertEqual(self.stubRemote.didRequestedMethod, .post)
        XCTAssertEqual(self.stubRemote.didRequestedPath, "dummy_calendar_api_host/v2/migration/color_themes")
        let params = self.stubRemote.didRequestedParams
        XCTAssertEqual(params?.keys.sorted(), ["ct1", "ct2"])
        let ct1Payload = params?["ct1"] as? [String: Any]
        XCTAssertEqual(ct1Payload?["name"] as? String, "theme1")
        XCTAssertEqual(ct1Payload?["colors"] as? [String: String], ["bg0": "#000000"])
        XCTAssertEqual(ct1Payload?["created_at"] as? Int, 100)
    }

    func testRepository_migrateCustomColorThemes_removeTempRows() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateCustomColorThemes()

        // then
        let countAfterMigration = try await repository.loadMigrationNeedEventCount()
        XCTAssertEqual(countAfterMigration, 4)
    }

    func testRepository_whenMigrateCustomColorThemesFails_keepTempRows() async throws {
        // given
        self.stubRemote = .init(responses: [
            .init(
                method: .post,
                endpoint: MigrationEndpoints.customColorThemes,
                resultJsonString: .failure(RuntimeError("failed"))
            )
        ])
        let repository = try await self.makeRepository()

        // when
        var failed = false
        do {
            try await repository.migrateCustomColorThemes()
        } catch {
            failed = true
        }

        // then
        XCTAssertEqual(failed, true)
        let countAfterFail = try await repository.loadMigrationNeedEventCount()
        XCTAssertEqual(countAfterFail, 6)
    }
}

// MARK: - 업로드한 데이터가 계정 로컬 DB 에 남는다

extension TemporaryUserDataMigrationRepositoryImpleTests {

    private func closeAccountDB() async throws {
        guard let service = self.accountSqliteService, let path = self.accountDBPath
        else { return }
        self.accountSqliteService = nil
        self.accountDBPath = nil
        try await service.async.close()
        try? FileManager.default.removeItem(atPath: path)
    }

    private func accountTagStorage() -> EventTagLocalStorageImple {
        return EventTagLocalStorageImple(
            sqliteService: self.accountSqliteService,
            environmentStorage: FakeEnvironmentStorage()
        )
    }

    private func accountDBCounts() async throws -> [String: Int] {
        let todoStorage = TodoLocalStorageImple(sqliteService: self.accountSqliteService)
        let detailStorage = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: self.accountSqliteService
        )
        let doneDetailStorage = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(
            sqliteService: self.accountSqliteService
        )
        return [
            "tags": try await self.accountTagStorage().loadAllTags().count,
            "todos": try await todoStorage.loadAllEvents().count,
            "dones": try await todoStorage.loadAllDoneEvents().count,
            "schedules": try await ScheduleEventLocalStorageImple(
                sqliteService: self.accountSqliteService
            ).loadAllEvents().count,
            "details": try await detailStorage.loadAll().count,
            "doneDetails": try await doneDetailStorage.loadAll().count,
            "themes": try await CustomColorThemeLocalStorageImple(
                sqliteService: self.accountSqliteService
            ).fetchThemes().count
        ]
    }

    private func migratings(
        _ repository: TemporaryUserDataMigrationRepositoryImple
    ) -> [() async throws -> Void] {
        return [
            repository.migrateEventTags,
            repository.migrateTodoEvents,
            repository.migrateScheduleEvents,
            repository.migrateEventDetails,
            repository.migrateDoneEvents,
            repository.migrateCustomColorThemes
        ]
    }

    func testRepository_migrationEventTag_writesToAccountDB() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateEventTags()

        // then
        let tags = try await self.accountTagStorage().loadAllTags()
        XCTAssertEqual(tags.map { $0.uuid }.sorted(), ["t1", "t2"])
        XCTAssertEqual(tags.first(where: { $0.uuid == "t1" })?.name, "n1")
    }

    func testRepository_migrationTodoEvents_writesToAccountDB() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateTodoEvents()

        // then
        let storage = TodoLocalStorageImple(sqliteService: self.accountSqliteService)
        let todos = try await storage.loadAllEvents()
        XCTAssertEqual(todos.map { $0.uuid }.sorted(), ["todo1", "todo2"])
        let todo1 = todos.first(where: { $0.uuid == "todo1" })
        XCTAssertEqual(todo1?.repeatingTurn, 4)
        XCTAssertEqual(todo1?.time, self.dummyTime)
    }

    func testRepository_migrationScheduleEvents_writesToAccountDB() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateScheduleEvents()

        // then
        let storage = ScheduleEventLocalStorageImple(sqliteService: self.accountSqliteService)
        let schedules = try await storage.loadAllEvents()
        XCTAssertEqual(schedules.map { $0.uuid }.sorted(), ["sc1", "sc2"])
        let sc1 = schedules.first(where: { $0.uuid == "sc1" })
        XCTAssertEqual(sc1?.showTurn, true)
        XCTAssertEqual(sc1?.repeatingTimeToExcludes, ["some"])
    }

    func testRepository_migrationEventDetails_writesToAccountDB() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateEventDetails()

        // then
        let storage = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: self.accountSqliteService
        )
        let details = try await storage.loadAll()
        XCTAssertEqual(details.map { $0.eventId }, ["todo1"])
        XCTAssertEqual(details.first?.memo, "memo")
        XCTAssertEqual(details.first?.place?.placeName, "place")

        let doneDetailStorage = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(
            sqliteService: self.accountSqliteService
        )
        let doneDetails = try await doneDetailStorage.loadAll()
        XCTAssertEqual(doneDetails.isEmpty, true)
    }

    func testRespository_migrateDoneTodoEvents_writesToAccountDBWithDetails() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateDoneEvents()

        // then
        let todoStorage = TodoLocalStorageImple(sqliteService: self.accountSqliteService)
        let dones = try await todoStorage.loadAllDoneEvents()
        XCTAssertEqual(dones.map { $0.uuid }.sorted(), ["d1", "d2"])
        XCTAssertEqual(dones.first(where: { $0.uuid == "d1" })?.originEventId, "todo1")
        XCTAssertEqual(dones.first(where: { $0.uuid == "d2" })?.originEventId, "todo2")

        let detailStorage = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(
            sqliteService: self.accountSqliteService
        )
        let details = try await detailStorage.loadAll()
        XCTAssertEqual(details.map { $0.eventId }, ["d1"])

        let eventDetailStorage = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: self.accountSqliteService
        )
        let eventDetails = try await eventDetailStorage.loadAll()
        XCTAssertEqual(eventDetails.isEmpty, true)
    }

    func testRepository_migrateCustomColorThemes_writesToAccountDB() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        try await repository.migrateCustomColorThemes()

        // then
        let storage = CustomColorThemeLocalStorageImple(sqliteService: self.accountSqliteService)
        let themes = try await storage.fetchThemes()
        XCTAssertEqual(themes.map { $0.uuid }, ["ct1", "ct2"])
        XCTAssertEqual(themes.first(where: { $0.uuid == "ct1" })?.name, "theme1")
    }

    func testRepository_whenUploadFails_notWriteToAccountDB() async throws {
        // given
        self.stubRemote = .init(responses: self.failureResponses)
        let repository = try await self.makeRepository()

        // when
        var failedCount = 0
        for migrating in self.migratings(repository) {
            do {
                try await migrating()
            } catch {
                failedCount += 1
            }
        }

        // then
        XCTAssertEqual(failedCount, 6)
        let counts = try await self.accountDBCounts()
        XCTAssertEqual(counts, [
            "tags": 0, "todos": 0, "schedules": 0,
            "details": 0, "dones": 0, "doneDetails": 0, "themes": 0
        ])
    }

    func testRepository_migrateAll_writesEveryKindIntoAccountDB() async throws {
        // given
        let repository = try await self.makeRepository()

        // when
        for migrating in self.migratings(repository) {
            try await migrating()
        }

        // then
        let counts = try await self.accountDBCounts()
        XCTAssertEqual(counts, [
            "tags": 2, "todos": 2, "schedules": 2,
            "details": 1, "dones": 2, "doneDetails": 1, "themes": 2
        ])
    }

    func testRepository_whenAccountDBWriteFails_migrationStillSucceeds() async throws {
        // given
        let repository = try await self.makeRepository()
        try await self.closeAccountDB()

        // when
        try await repository.migrateCustomColorThemes()

        // then
        XCTAssertEqual(
            self.stubRemote.didRequestedPath, "dummy_calendar_api_host/v2/migration/color_themes"
        )
        let countAfterMigration = try await repository.loadMigrationNeedEventCount()
        XCTAssertEqual(countAfterMigration, 4)
    }
}

extension TemporaryUserDataMigrationRepositoryImpleTests {
    
    private var okReponse: String {
        return """
        { "status": "ok" }
        """
    }
    
    private var failureResponses: [StubRemoteAPI.Response] {
        let endpoints: [MigrationEndpoints] = [
            .eventTags, .todos, .schedules, .eventDetails, .doneTodos, .doneTodoDetails, .customColorThemes
        ]
        return endpoints.map {
            .init(
                method: .post,
                endpoint: $0,
                resultJsonString: .failure(RuntimeError("failed"))
            )
        }
    }

    private var responses: [StubRemoteAPI.Response] {
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
            .init(
                method: .post,
                endpoint: MigrationEndpoints.doneTodos,
                resultJsonString: .success(self.okReponse)
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.doneTodoDetails,
                resultJsonString: .success(self.okReponse)
            ),
            .init(
                method: .post,
                endpoint: MigrationEndpoints.customColorThemes,
                resultJsonString: .success(self.okReponse)
            ),
        ]
    }
}

