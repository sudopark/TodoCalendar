//
//  AppDataMigrationImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 3/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import Extensions
import SQLiteService

@testable import Repository


@Suite("AppDataMigrationImpleTests", .serialized)
final class AppDataMigrationImpleTests {

    private let accountId = "test@google.com"
    private let googleServiceId = GoogleCalendarService.id

    // 테스트마다 다른 이름을 준다 — 고정 파일명이면 앞 테스트의 커넥션이 살아 있는 채로
    // 뒤 테스트가 같은 vnode 를 열어 프로세스가 죽는다
    private let dbNameSuffix: String = UUID().uuidString

    private func dbPath(_ name: String) -> String {
        try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name)_\(dbNameSuffix).db")
            .path
    }

    private var mainDBPath: String { dbPath("migration_main") }
    private var googleDBPath: String { dbPath("migration_google") }

    private var openedServices: [SQLiteService] = []

    // 커넥션을 닫은 뒤 파일을 지운다 — 열린 채로 unlink 하면 sqlite 가
    // `vnode unlinked while in use` 로 프로세스를 죽인다. 닫기를 `Task` 로 떼면 순서가 안 선다
    private func cleanup() {
        openedServices.forEach { _ = $0.close() }
        openedServices.removeAll()
        [mainDBPath, googleDBPath]
            .forEach { try? FileManager.default.removeItem(atPath: $0) }
    }

    private func openDB(at path: String) async throws -> SQLiteService {
        let service = SQLiteService()
        try await service.async.open(path: path)
        openedServices.append(service)
        return service
    }

    private func openMainDB() async throws -> SQLiteService {
        return try await openDB(at: mainDBPath)
    }

    private func makePool() async throws -> ExternalCalendarSQLiteConnectionPoolImple {
        let pool = ExternalCalendarSQLiteConnectionPoolImple(dbPathMap: [
            googleServiceId: googleDBPath
        ])
        try await pool.open(serviceId: googleServiceId)
        openedServices.append(try await pool.connection(serviceId: googleServiceId))
        return pool
    }

    private func makeMigration(
        mainDB: SQLiteService,
        pool: any ExternalCalendarDBConnectionPool,
        flagStorage: FakeEnvironmentStorage = .init(),
        dbVersion: Int32 = 7
    ) -> AppDataMigrationImple {
        return .init(
            mainDB: mainDB,
            googleCalendarDBPool: pool,
            migrationFlagStorage: flagStorage,
            dbVersion: dbVersion
        )
    }

    private func insertOldColors(_ mainDB: SQLiteService) async throws {
        try await mainDB.async.run { db in
            try db.createTableOrNot(OldGoogleCalendarColorsTable.self)
            let entities: [OldGoogleCalendarColorsTable.Entity] = [
                .init(calendar: "1", .init(foregroundHex: "#ffffff", backgroudHex: "#111111")),
                .init(event: "2", .init(foregroundHex: "#ffffff", backgroudHex: "#222222"))
            ]
            try db.insert(OldGoogleCalendarColorsTable.self, entities: entities)
        }
    }

    private func insertOldTags(_ mainDB: SQLiteService, tagId: String = "cal1") async throws {
        try await mainDB.async.run { db in
            try db.createTableOrNot(OldGoogleCalendarEventTagTable.self)
            var tag = GoogleCalendar.Tag(id: tagId, name: "Calendar \(tagId)")
            tag.backgroundColorHex = "#aaaaaa"
            try db.insert(OldGoogleCalendarEventTagTable.self, entities: [tag])
        }
    }

    private func insertOldEventOrigins(_ mainDB: SQLiteService) async throws -> [String] {
        let eventIds = ["event1", "event2"]
        try await mainDB.async.run { db in
            try db.createTableOrNot(OldGoogleCalendarEventOriginTable.self)
            try db.createTableOrNot(EventTimeTable.self)
            let origins: [OldGoogleCalendarEventOriginTable.Entity] = eventIds.map {
                .init("cal1", "Asia/Seoul", GoogleCalendar.EventOrigin(id: $0, summary: "Event \($0)"))
            }
            try db.insert(OldGoogleCalendarEventOriginTable.self, entities: origins)
            let times: [EventTimeTable.Entity] = eventIds.map {
                EventTimeTable.Entity($0, .at(0), nil)
            }
            try db.insert(EventTimeTable.self, entities: times)
        }
        return eventIds
    }

    private func loadGoogleDBColors(_ pool: ExternalCalendarSQLiteConnectionPoolImple) async throws -> [GoogleCalendarColorsTable.Entity] {
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        return try await googleDB.async.run { db in
            try? db.createTableOrNot(GoogleCalendarColorsTable.self)
            return (try? db.load(GoogleCalendarColorsTable.self, query: GoogleCalendarColorsTable.selectAll())) ?? []
        }
    }

    private func loadGoogleDBTags(_ pool: ExternalCalendarSQLiteConnectionPoolImple) async throws -> [GoogleCalendarEventTagTable.Entity] {
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        return try await googleDB.async.run { db in
            try? db.createTableOrNot(GoogleCalendarEventTagTable.self)
            return (try? db.load(GoogleCalendarEventTagTable.self, query: GoogleCalendarEventTagTable.selectAll())) ?? []
        }
    }

    private func loadGoogleDBOrigins(_ pool: ExternalCalendarSQLiteConnectionPoolImple) async throws -> [GoogleCalendarEventOriginTable.Entity] {
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        return try await googleDB.async.run { db in
            try? db.createTableOrNot(GoogleCalendarEventOriginTable.self)
            return (try? db.load(GoogleCalendarEventOriginTable.self, query: GoogleCalendarEventOriginTable.selectAll())) ?? []
        }
    }

    private func loadMainDBEventTimes(_ mainDB: SQLiteService) async throws -> [EventTimeTable.Entity] {
        return try await mainDB.async.run { db in
            try? db.createTableOrNot(EventTimeTable.self)
            return (try? db.load(EventTimeTable.self, query: EventTimeTable.selectAll())) ?? []
        }
    }

    private var dummyV0TodoEvent: TodoEventTableV0.Entity {
        return TodoEventTableV0.Entity(
            uuid: "seed-uuid",
            name: "seed-name",
            createTimeStamp: 1100,
            eventTagId: "seed-tag",
            repeatingStart: 2200,
            repeatingOption: "seed-option",
            repeatingEnd: 3300,
            notificationOptions: "seed-notification"
        )
    }

    // 커넥션을 닫은 뒤 파일을 지운다 — 열린 채로 unlink 하면 sqlite 가
    // "vnode unlinked while in use" 로 프로세스를 죽인다
    private func withMigrationDB(
        at path: String,
        userVersion: Int32 = 0,
        seed: @escaping (any DataBase) throws -> Void = { _ in },
        body: (SQLiteService, any ExternalCalendarDBConnectionPool) async throws -> Void
    ) async throws {
        let mainDB = try await openDB(at: path)

        let outcome: Result<Void, any Error>
        do {
            try await mainDB.async.run { db in
                try seed(db)
                try db.updateUserVersion(userVersion)
            }
            try await body(mainDB, makePool())
            outcome = .success(())
        } catch {
            outcome = .failure(error)
        }

        cleanup()
        try outcome.get()
    }

    // 일곱 스텝이 건드리는 여섯 테이블을 전부 v0 시점 선언으로 세운다 —
    // 하나라도 빠지면 그 스텝이 테이블 없음으로 빠져 돌았는지 구분이 안 된다
    private func seedEveryV0Table(_ db: any DataBase) throws {
        try db.createTableOrNot(TodoEventTableV0.self)
        try db.insert(TodoEventTableV0.self, entities: [self.dummyV0TodoEvent], shouldReplace: true)
        try db.createTableOrNot(ScheduleEventTableV0.self)
        try db.insert(ScheduleEventTableV0.self, entities: [self.dummySchedule], shouldReplace: true)
        try db.createTableOrNot(PendingDoneTodoEventTableV0.self)
        try db.insert(
            PendingDoneTodoEventTableV0.self,
            entities: self.dummyPendingDoneTodos.map { PendingDoneTodoEventTableV0.Entity($0) },
            shouldReplace: true
        )
        try db.createTableOrNot(OldGoogleCalendarEventOriginTableV1.self)
        try db.insert(
            OldGoogleCalendarEventOriginTableV1.self, entities: [self.dummyEventOrigin], shouldReplace: true
        )
        try db.createTableOrNot(OldGoogleCalendarEventTagTableV2.self)
        try db.insert(
            OldGoogleCalendarEventTagTableV2.self, entities: [self.dummyGoogleTag], shouldReplace: true
        )
        try db.createTableOrNot(EventUploadPendingQueueTableV4.self)
        try db.insert(
            EventUploadPendingQueueTableV4.self, entities: [.init(self.dummyUploadingTask)], shouldReplace: true
        )
    }

    private func requireSelectSucceeds(_ mainDB: SQLiteService, _ statement: String) async throws {
        try await mainDB.async.run { db in
            try db.execute(statement)
        }
    }

    private func requireMigratedColumnsExist(_ mainDB: SQLiteService) async throws {
        try await requireSelectSucceeds(mainDB, "SELECT repeating_count, repeating_turn FROM TodoEvents;")
    }

    private var dummySchedule: ScheduleEventTableV0.Entity {
        let repeating = EventRepeating(
            repeatingStartTime: 2200,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        let event = ScheduleEvent(uuid: "seed-schedule", name: "seed-schedule-name", time: .at(100))
            |> \.eventTagId .~ EventTagId("seed-schedule-tag")
            |> \.showTurn .~ true
            |> \.repeating .~ pure(repeating)
        let entity = ScheduleEventTable.Entity(event)
        return ScheduleEventTableV0.Entity(
            uuid: entity.uuid,
            name: entity.name,
            eventTagId: entity.eventTagId,
            repeatingStart: entity.repeatingStart,
            repeatingOption: entity.repeatingOption,
            repeatingEnd: entity.repeatingEnd,
            showTurn: entity.showTurn,
            excludeTimes: entity.excludeTimes,
            notificationOptions: entity.notificationOptions
        )
    }

    // 복사 목록의 컬럼마다 값을 싣는다 — 두 행으로 갈라야 상호 배타인
    // repeating_end 와 repeating_count 를 둘 다 덮는다
    private var dummyPendingDoneTodos: [PendingDoneTodoEventTable.Entity] {
        let countEnd = EventRepeating(
            repeatingStartTime: 2200,
            repeatOption: EventRepeatingOptions.EveryDay()
        ) |> \.repeatingEndOption .~ .count(44)
        let timeEnd = EventRepeating(
            repeatingStartTime: 3300,
            repeatOption: EventRepeatingOptions.EveryDay()
        ) |> \.repeatingEndOption .~ .until(8800)

        let allDayTodo = TodoEvent(uuid: "seed-pending", name: "seed-pending-name")
            |> \.creatTimeStamp .~ 1100
            |> \.eventTagId .~ EventTagId("seed-pending-tag")
            |> \.time .~ .allDay(5500..<5600, secondsFromGMT: 32400)
            |> \.repeating .~ pure(countEnd)
            |> \.notificationOptions .~ [.before(seconds: 300)]
        let periodTodo = TodoEvent(uuid: "seed-pending-2", name: "seed-pending-2-name")
            |> \.creatTimeStamp .~ 9900
            |> \.time .~ .period(7700..<7800)
            |> \.repeating .~ pure(timeEnd)

        return [
            .init(allDayTodo),
            .init(periodTodo)
        ]
    }

    private var dummyEventOrigin: OldGoogleCalendarEventOriginTable.Entity {
        return .init(
            "seed-calendar",
            "Asia/Seoul",
            GoogleCalendar.EventOrigin(id: "seed-origin", summary: "seed-origin-summary")
        )
    }

    private var dummyGoogleTag: GoogleCalendar.Tag {
        var tag = GoogleCalendar.Tag(id: "seed-tag", name: "seed-tag-name")
        tag.backgroundColorHex = "seed-background"
        return tag
    }

    private func loadEventOrigins(_ mainDB: SQLiteService) async throws -> [OldGoogleCalendarEventOriginTable.Entity] {
        return try await mainDB.async.run([OldGoogleCalendarEventOriginTable.Entity].self) { db in
            try db.load(
                OldGoogleCalendarEventOriginTable.self,
                query: OldGoogleCalendarEventOriginTable.selectAll()
            )
        }
    }

    private var dummyV1TodoEvent: TodoEventTableV1.Entity {
        return TodoEventTableV1.Entity(
            uuid: "seed-v1-uuid",
            name: "seed-v1-name",
            createTimeStamp: 1100,
            eventTagId: "seed-v1-tag",
            repeatingStart: 2200,
            repeatingOption: "seed-v1-option",
            repeatingEnd: 3300,
            notificationOptions: "seed-v1-notification",
            repeatingEndCount: 44
        )
    }

    // uploadFailCount 는 컬럼 기본값 0 과 다른 값을 준다 — 같으면 복사 목록에서 빠져도 안 드러난다
    private var dummyUploadingTask: EventUploadingTask {
        return EventUploadingTask(
            timestamp: 1100,
            dataType: .schedule,
            uuid: "seed-upload-uuid",
            isRemovingTask: true
        ) |> \.uploadFailCount .~ 7
    }

    // uuid 가 같고 dataType 만 다르다 — v4 의 unique 제약이 살아 있으면 INSERT 가 던진다
    private var dummyUploadingTaskSharingUUID: EventUploadingTask {
        return EventUploadingTask(
            timestamp: 2200,
            dataType: .eventDetail,
            uuid: "seed-upload-uuid",
            isRemovingTask: false
        )
    }

    private func loadUploadingTasks(_ mainDB: SQLiteService) async throws -> [EventUploadingTask] {
        return try await mainDB.async.run([EventUploadingTask].self) { db in
            try db.load(
                EventUploadPendingQueueTable.self,
                query: EventUploadPendingQueueTable.selectAll()
            )
            .map { try $0.asUploadingTask() }
        }
    }

    private func loadPendingDoneTodos(_ mainDB: SQLiteService) async throws -> [PendingDoneTodoEventTable.Entity] {
        return try await mainDB.async.run([PendingDoneTodoEventTable.Entity].self) { db in
            try db.load(
                PendingDoneTodoEventTable.self,
                query: PendingDoneTodoEventTable.selectAll()
            )
        }
    }

    private func decodedNotificationOptions(_ text: String?) -> [EventNotificationTimeOption]? {
        return text?.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode([EventNotificationTimeOptionMapper].self, from: $0) }
            .map { $0.map { $0.option } }
    }

    private func decodedRepeatOptionIsEveryDay(_ text: String?) -> Bool {
        guard let data = text?.data(using: .utf8),
              let mapper = try? JSONDecoder().decode(
                EventRepeatingOptionCodableMapper.self, from: data
              )
        else { return false }
        return mapper.option is EventRepeatingOptions.EveryDay
    }

    private func loadSchedules(_ mainDB: SQLiteService) async throws -> [ScheduleEventTable.Entity] {
        return try await mainDB.async.run([ScheduleEventTable.Entity].self) { db in
            try db.load(ScheduleEventTable.self, query: ScheduleEventTable.selectAll())
        }
    }

    private func loadTodoEvents(_ mainDB: SQLiteService) async throws -> [TodoEventTable.Entity] {
        return try await mainDB.async.run([TodoEventTable.Entity].self) { db in
            try db.load(TodoEventTable.self, query: TodoEventTable.selectAll())
        }
    }

    private func loadUserVersion(_ mainDB: SQLiteService) async throws -> Int32 {
        return try await mainDB.async.run(Int32.self) { db in
            try db.userVersion()
        }
    }

    private var dummyCurrentTodoEvent: TodoEventTable.Entity {
        return TodoEventTable.Entity(
            uuid: "fresh-uuid",
            name: "fresh-name",
            createTimeStamp: 1100,
            eventTagId: "fresh-tag",
            repeatingStart: 2200,
            repeatingOption: "fresh-option",
            repeatingEnd: 3300,
            notificationOptions: "fresh-notification",
            repeatingEndCount: 44,
            repeatingTurn: 55
        )
    }

    private func insertCurrentTodoEvent(_ mainDB: SQLiteService) async throws {
        try await mainDB.async.run { db in
            try db.insert(TodoEventTable.self, entities: [self.dummyCurrentTodoEvent], shouldReplace: true)
        }
    }

    private func expectSeededRowUnchanged(_ row: TodoEventTable.Entity) {
        #expect(row.uuid == "seed-uuid")
        #expect(row.name == "seed-name")
        #expect(row.createTimeStamp == 1100)
        #expect(row.eventTagId == "seed-tag")
        #expect(row.repeatingStart == 2200)
        #expect(row.repeatingOption == "seed-option")
        #expect(row.repeatingEnd == 3300)
        #expect(row.notificationOptions == "seed-notification")
        #expect(row.repeatingEndCount == nil)
        #expect(row.repeatingTurn == nil)
    }
}


// MARK: - 마이그레이션 정상 수행

extension AppDataMigrationImpleTests {

    // mainDB의 구 데이터(colors, tags, origins, eventTimes)가 google_calendar.db로 이동
    @Test func migration_movesAllDataToGoogleDB() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        let pool = try await makePool()

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)
        let googleDB = try await pool.connection(serviceId: googleServiceId)
        let times: [EventTimeTable.Entity] = try await googleDB.async.run { db in
            try? db.createTableOrNot(EventTimeTable.self)
            return (try? db.load(EventTimeTable.self, query: EventTimeTable.selectAll())) ?? []
        }

        #expect(colors.count == 2)
        #expect(colors.allSatisfy { $0.accountId == accountId })
        #expect(tags.count == 1)
        #expect(tags.allSatisfy { $0.accountId == accountId })
        #expect(origins.count == 2)
        #expect(origins.allSatisfy { $0.accountId == accountId })
        #expect(times.count == 2)
    }

    // google_calendar DB 연결이 없으면 마이그레이션을 건너뛰고 flag도 설정하지 않음
    @Test func migration_whenNoConnection_skipsAndDoesNotSetFlag() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        let failingPool = FailingExternalCalendarSQLiteConnectionPool()
        let flagStorage = FakeEnvironmentStorage()
        let migration = makeMigration(mainDB: mainDB, pool: failingPool, flagStorage: flagStorage)

        await migration.migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let flag: Bool? = flagStorage.load("google_calendar_migrated")
        #expect(flag != true)
    }

    // 마이그레이션 이후 mainDB의 구 테이블 및 이벤트 타임 레코드 삭제
    @Test func migration_cleansUpOldDataAfterCompletion() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        let pool = try await makePool()

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let remainingTimes = try await loadMainDBEventTimes(mainDB)
        #expect(remainingTimes.isEmpty)
    }

    // 한 번 마이그레이션 완료 이후 중복 실행하더라도 이미 이동한 데이터에 영향 없음
    @Test func migration_doesNotRunAgainAfterCompletion() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        let pool = try await makePool()

        let flagStorage = FakeEnvironmentStorage()
        let migration = makeMigration(mainDB: mainDB, pool: pool, flagStorage: flagStorage)

        // 첫 번째 마이그레이션: tag "cal1" 이동
        try await insertOldTags(mainDB, tagId: "cal1")
        await migration.migrateGoogleCalendarDataIfNeeded(accountId: accountId)
        let tagsAfterFirst = try await loadGoogleDBTags(pool)

        // 두 번째 실행 전에 mainDB에 새 데이터 추가
        try await insertOldTags(mainDB, tagId: "cal2")
        await migration.migrateGoogleCalendarDataIfNeeded(accountId: accountId)
        let tagsAfterSecond = try await loadGoogleDBTags(pool)

        // 두 번째 실행은 스킵되어야 하므로 카운트가 늘지 않아야 함
        #expect(tagsAfterFirst.count == 1)
        #expect(tagsAfterSecond.count == tagsAfterFirst.count)
    }
}


// MARK: - 마이그레이션 실패

extension AppDataMigrationImpleTests {

    // mainDB read 실패 시 완료 처리 → 이후 호출에서 스킵됨
    @Test func migration_whenReadFails_marksCompletedAndSkipsNextTime() async throws {
        defer { cleanup() }
        let pool = try await makePool()

        let flagStorage = FakeEnvironmentStorage()

        // DB를 열지 않은 상태 → read 실패 → 완료로 처리
        let closedMainDB = SQLiteService()
        await makeMigration(mainDB: closedMainDB, pool: pool, flagStorage: flagStorage)
            .migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        // 두 번째 호출: valid mainDB에 데이터가 있어도 스킵되어야 함
        let validMainDB = try await openMainDB()
        try await insertOldTags(validMainDB)

        await makeMigration(mainDB: validMainDB, pool: pool, flagStorage: flagStorage)
            .migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let tags = try await loadGoogleDBTags(pool)
        #expect(tags.isEmpty)
    }
}


// MARK: - 마이그레이션할 데이터 없는 엣지 케이스

extension AppDataMigrationImpleTests {

    // 구 DB에 데이터가 하나도 없어도 정상 완료
    @Test func migration_whenNoData_completesSuccessfully() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        let pool = try await makePool()

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)
        // throw 없이 완료되면 성공
    }

    // 컬러만 없는 경우 — 태그, 이벤트는 정상 이동
    @Test func migration_whenNoColors_migratesTagsAndEvents() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        let pool = try await makePool()

        try await insertOldTags(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)

        #expect(colors.isEmpty)
        #expect(tags.count == 1)
        #expect(origins.count == 2)
    }

    // 태그만 없는 경우 — 컬러, 이벤트는 정상 이동
    @Test func migration_whenNoTags_migratesColorsAndEvents() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        let pool = try await makePool()

        try await insertOldColors(mainDB)
        let _ = try await insertOldEventOrigins(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)

        #expect(colors.count == 2)
        #expect(tags.isEmpty)
        #expect(origins.count == 2)
    }

    // 이벤트만 없는 경우 — 컬러, 태그는 정상 이동
    @Test func migration_whenNoEvents_migratesColorsAndTags() async throws {
        defer { cleanup() }
        let mainDB = try await openMainDB()
        let pool = try await makePool()

        try await insertOldColors(mainDB)
        try await insertOldTags(mainDB)

        await makeMigration(mainDB: mainDB, pool: pool).migrateGoogleCalendarDataIfNeeded(accountId: accountId)

        let colors = try await loadGoogleDBColors(pool)
        let tags = try await loadGoogleDBTags(pool)
        let origins = try await loadGoogleDBOrigins(pool)

        #expect(colors.count == 2)
        #expect(tags.count == 1)
        #expect(origins.isEmpty)
    }
}


// MARK: - 마이그레이션 전 구간

extension AppDataMigrationImpleTests {

    // 여섯 테이블을 v0 시점 선언으로 세우고 전 구간을 태우면 일곱 스텝이 다 돌고 데이터가 남는다
    @Test func runDBMigration_fromV0_runsEveryStepAndKeepsData() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, seed: { db in
            try self.seedEveryV0Table(db)
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool).runDBMigration()

            // then — 스텝마다 그 스텝이 더한 컬럼이 물리적으로 있다
            try await self.requireMigratedColumnsExist(mainDB)
            try await self.requireSelectSucceeds(mainDB, "SELECT repeating_count FROM Schedules;")
            try await self.requireSelectSucceeds(mainDB, "SELECT repeating_count, repeating_turn FROM PendingDoneTodoEvent;")
            try await self.requireSelectSucceeds(mainDB, "SELECT status, visibility FROM google_calendar_event_origin;")
            try await self.requireSelectSucceeds(mainDB, "SELECT is_selected FROM google_calendar_list;")
            try await self.requireSelectSucceeds(mainDB, "SELECT upload_fail_count FROM event_upload_pending_queue;")

            let todos = try await self.loadTodoEvents(mainDB)
            let schedules = try await self.loadSchedules(mainDB)
            let pendingDones = try await self.loadPendingDoneTodos(mainDB)
            let origins = try await self.loadEventOrigins(mainDB)
            let uploads = try await self.loadUploadingTasks(mainDB)
            let version = try await self.loadUserVersion(mainDB)

            self.expectSeededRowUnchanged(try #require(todos.first))
            #expect(try #require(schedules.first).uuid == "seed-schedule")
            #expect(pendingDones.count == 2)
            let pendingAllDay = try #require(pendingDones.first { $0.uuid == "seed-pending" }).asTodoEvent()
            let pendingPeriod = try #require(pendingDones.first { $0.uuid == "seed-pending-2" }).asTodoEvent()
            #expect(pendingAllDay.time == .allDay(5500..<5600, secondsFromGMT: 32400))
            #expect(pendingAllDay.notificationOptions == [.before(seconds: 300)])
            // v0 테이블엔 repeating_count 자리가 없어 시드가 버려지고, 0→1 은 기존 행을 NULL 로 채운다
            #expect(pendingAllDay.repeating?.repeatingEndOption == nil)
            #expect(pendingPeriod.time == .period(7700..<7800))
            #expect(pendingPeriod.repeating?.repeatingEndOption?.endTime == 8800)
            #expect(try #require(origins.first).origin.id == "seed-origin")
            #expect(try #require(uploads.first).uuid == "seed-upload-uuid")
            #expect(version == 7)
        }
    }

    // 같은 DB 에 두 번 태워도 스키마와 데이터가 그대로다 — 두 번째 실행은 기록된 버전 때문에 스텝을 안 탄다
    @Test func runDBMigration_whenRunTwice_schemaAndDataUnchanged() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, seed: { db in
            try self.seedEveryV0Table(db)
        }) { mainDB, pool in
            // when
            let migration = self.makeMigration(mainDB: mainDB, pool: pool)
            try await migration.runDBMigration()
            try await migration.runDBMigration()

            // then
            try await self.requireMigratedColumnsExist(mainDB)
            let loaded = try await self.loadTodoEvents(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            #expect(loaded.count == 1)
            self.expectSeededRowUnchanged(try #require(loaded.first))
            #expect(version == 7)
        }
    }

    // 빈 DB 에 전 구간을 태워도 TodoEvents 가 살아남고 두 마이그레이션 컬럼을 갖는다
    @Test func runDBMigration_onEmptyDB_keepsTodoEventTable() async throws {
        // given
        try await withMigrationDB(at: mainDBPath) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool).runDBMigration()

            // then
            try await self.requireMigratedColumnsExist(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            #expect(version == 7)

            try await self.insertCurrentTodoEvent(mainDB)
            let loaded = try await self.loadTodoEvents(mainDB)
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.uuid == "fresh-uuid")
            #expect(row.name == "fresh-name")
            #expect(row.createTimeStamp == 1100)
            #expect(row.eventTagId == "fresh-tag")
            #expect(row.repeatingStart == 2200)
            #expect(row.repeatingOption == "fresh-option")
            #expect(row.repeatingEnd == 3300)
            #expect(row.notificationOptions == "fresh-notification")
            #expect(row.repeatingEndCount == 44)
            #expect(row.repeatingTurn == 55)
        }
    }
}


// MARK: - 스텝 단위 마이그레이션 회귀

extension AppDataMigrationImpleTests {

    // 0→1 만 태우면 TodoEvents 에 repeating_count 가 붙고 시드한 여덟 값이 자리대로 남는다
    @Test func runDBMigration_v0ToV1_addsRepeatingCountToTodoEvents() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 0, seed: { db in
            try db.createTableOrNot(TodoEventTableV0.self)
            try db.insert(TodoEventTableV0.self, entities: [self.dummyV0TodoEvent], shouldReplace: true)
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 1).runDBMigration()

            // then
            try await self.requireSelectSucceeds(mainDB, "SELECT repeating_count FROM TodoEvents;")
            let loaded = try await mainDB.async.run([TodoEventTableV1.Entity].self) { db in
                try db.load(TodoEventTableV1.self, query: TodoEventTableV1.selectAll())
            }
            let version = try await self.loadUserVersion(mainDB)
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.uuid == "seed-uuid")
            #expect(row.name == "seed-name")
            #expect(row.createTimeStamp == 1100)
            #expect(row.eventTagId == "seed-tag")
            #expect(row.repeatingStart == 2200)
            #expect(row.repeatingOption == "seed-option")
            #expect(row.repeatingEnd == 3300)
            #expect(row.notificationOptions == "seed-notification")
            #expect(row.repeatingEndCount == nil)
            #expect(version == 1)
        }
    }

    // 0→1 만 태우면 Schedules 에 repeating_count 가 붙고 시드한 행이 그대로 남는다
    @Test func runDBMigration_v0ToV1_addsRepeatingCountToSchedules() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 0, seed: { db in
            try db.createTableOrNot(ScheduleEventTableV0.self)
            try db.insert(ScheduleEventTableV0.self, entities: [self.dummySchedule], shouldReplace: true)
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 1).runDBMigration()

            // then
            try await self.requireSelectSucceeds(mainDB, "SELECT repeating_count FROM Schedules;")
            let loaded = try await self.loadSchedules(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.uuid == "seed-schedule")
            #expect(row.name == "seed-schedule-name")
            #expect(row.eventTagId == "seed-schedule-tag")
            #expect(row.showTurn == true)
            #expect(row.repeatingStart == 2200)
            #expect(self.decodedRepeatOptionIsEveryDay(row.repeatingOption))
            // 0→1 이 붙인 컬럼은 기존 행에서 NULL 이라 종료 옵션이 안 잡힌다
            #expect(row.repeatingEnd == nil)
            #expect(row.repeatingEndCount == nil)
            #expect(version == 1)
        }
    }

    // 0→1 만 태우면 PendingDoneTodoEvent 에 repeating_count 가 붙는다
    @Test func runDBMigration_v0ToV1_addsRepeatingCountToPendingDoneTodos() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 0, seed: { db in
            try db.createTableOrNot(PendingDoneTodoEventTableV0.self)
            try db.insert(
                PendingDoneTodoEventTableV0.self,
                entities: self.dummyPendingDoneTodos.map { PendingDoneTodoEventTableV0.Entity($0) },
                shouldReplace: true
            )
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 1).runDBMigration()

            // then
            try await self.requireSelectSucceeds(mainDB, "SELECT repeating_count FROM PendingDoneTodoEvent;")
            let loaded = try await mainDB.async.run([PendingDoneTodoEventTableV1.EntityType].self) { db in
                try db.load(PendingDoneTodoEventTableV1.self, query: PendingDoneTodoEventTableV1.selectAll())
            }
            let version = try await self.loadUserVersion(mainDB)
            let row = try #require(loaded.first { $0.uuid == "seed-pending" })
            #expect(loaded.count == 2)
            #expect(row.name == "seed-pending-name")
            #expect(row.createTimeStamp == 1100)
            #expect(row.eventTagId == "seed-pending-tag")
            #expect(self.decodedNotificationOptions(row.notificationOptions) == [.before(seconds: 300)])
            #expect(row.repeatingStart == 2200)
            #expect(self.decodedRepeatOptionIsEveryDay(row.repeatingOption))
            // 0→1 이 붙인 컬럼은 기존 행에서 NULL 이라 종료 옵션이 안 잡힌다
            #expect(row.repeatingEnd == nil)
            #expect(row.repeatingEndCount == nil)
            #expect(version == 1)
        }
    }

    // 1→2 만 태우면 google_calendar_event_origin 에 status 가 붙고 시드한 행이 그대로 남는다
    @Test func runDBMigration_v1ToV2_addsStatusToGoogleEventOrigin() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 1, seed: { db in
            try db.createTableOrNot(OldGoogleCalendarEventOriginTableV1.self)
            try db.insert(
                OldGoogleCalendarEventOriginTableV1.self,
                entities: [self.dummyEventOrigin],
                shouldReplace: true
            )
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 2).runDBMigration()

            // then
            try await self.requireSelectSucceeds(mainDB, "SELECT status FROM google_calendar_event_origin;")
            let loaded = try await self.loadEventOrigins(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.calendarId == "seed-calendar")
            #expect(row.defaultTimeZone == "Asia/Seoul")
            #expect(row.origin.id == "seed-origin")
            #expect(row.origin.summary == "seed-origin-summary")
            #expect(row.origin.status == nil)
            #expect(version == 2)
        }
    }

    // 2→3 만 태우면 google_calendar_list 에 is_selected 가 붙는다
    @Test func runDBMigration_v2ToV3_addsIsSelectedToGoogleCalendarList() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 2, seed: { db in
            try db.createTableOrNot(OldGoogleCalendarEventTagTableV2.self)
            try db.insert(
                OldGoogleCalendarEventTagTableV2.self,
                entities: [self.dummyGoogleTag],
                shouldReplace: true
            )
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 3).runDBMigration()

            // then
            try await self.requireSelectSucceeds(mainDB, "SELECT is_selected FROM google_calendar_list;")
            let loaded = try await mainDB.async.run([GoogleCalendar.Tag].self) { db in
                try db.load(
                    OldGoogleCalendarEventTagTable.self,
                    query: OldGoogleCalendarEventTagTable.selectAll()
                )
            }
            let version = try await self.loadUserVersion(mainDB)
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.id == "seed-tag")
            #expect(row.name == "seed-tag-name")
            #expect(row.backgroundColorHex == "seed-background")
            #expect(row.isSelected == nil)
            // access_role 은 메인 DB 에 물리적으로 없다 — #863 이 선언에만 더했고 마이그레이션이 없다
            #expect(row.accessRole == nil)
            #expect(version == 3)
        }
    }

    // 3→4 만 태우면 google_calendar_event_origin 에 visibility 가 붙고 시드한 행이 그대로 남는다
    @Test func runDBMigration_v3ToV4_addsVisibilityToGoogleEventOrigin() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 3, seed: { db in
            try db.createTableOrNot(OldGoogleCalendarEventOriginTableV3.self)
            try db.insert(
                OldGoogleCalendarEventOriginTableV3.self,
                entities: [self.dummyEventOrigin],
                shouldReplace: true
            )
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 4).runDBMigration()

            // then
            try await self.requireSelectSucceeds(mainDB, "SELECT visibility FROM google_calendar_event_origin;")
            let loaded = try await self.loadEventOrigins(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.calendarId == "seed-calendar")
            #expect(row.origin.id == "seed-origin")
            #expect(row.origin.visibility == nil)
            #expect(version == 4)
        }
    }

    // 4→5 만 태우면 uuid 의 unique 제약이 떨어져 같은 uuid 의 다른 dataType 을 넣을 수 있다
    @Test func runDBMigration_v4ToV5_dropsUniqueConstraintOnUUID() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 4, seed: { db in
            try db.createTableOrNot(EventUploadPendingQueueTableV4.self)
            try db.insert(
                EventUploadPendingQueueTableV4.self,
                entities: [.init(self.dummyUploadingTask)],
                shouldReplace: true
            )
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 5).runDBMigration()

            // then
            try await self.requireSelectSucceeds(
                mainDB,
                "SELECT timestamp, data_type, uuid, is_remove, upload_fail_count FROM event_upload_pending_queue;"
            )
            await #expect(throws: (any Error).self) {
                try await self.requireSelectSucceeds(mainDB, "SELECT uuid FROM event_upload_pending_queue_v4;")
            }

            // unique 가 떨어졌으므로 uuid 가 겹치는 행이 하나 더 들어간다
            try await mainDB.async.run { db in
                try db.insert(
                    EventUploadPendingQueueTable.self,
                    entities: [.init(self.dummyUploadingTaskSharingUUID)],
                    shouldReplace: false
                )
            }

            let loaded = try await self.loadUploadingTasks(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            #expect(loaded.count == 2)
            #expect(loaded.allSatisfy { $0.uuid == "seed-upload-uuid" })
            let migrated = try #require(loaded.first { $0.dataType == .schedule })
            #expect(migrated.timestamp == 1100)
            #expect(migrated.isRemovingTask == true)
            #expect(migrated.uploadFailCount == 7)
            #expect(version == 5)
        }
    }

    // 5→6 만 태우면 TodoEvents 에 repeating_turn 이 붙고 아홉 값이 자리대로 남는다
    @Test func runDBMigration_v5ToV6_addsRepeatingTurnToTodoEvents() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 5, seed: { db in
            try db.createTableOrNot(TodoEventTableV1.self)
            try db.insert(TodoEventTableV1.self, entities: [self.dummyV1TodoEvent], shouldReplace: true)
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 6).runDBMigration()

            // then
            try await self.requireSelectSucceeds(mainDB, "SELECT repeating_turn FROM TodoEvents;")
            let loaded = try await self.loadTodoEvents(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.uuid == "seed-v1-uuid")
            #expect(row.name == "seed-v1-name")
            #expect(row.createTimeStamp == 1100)
            #expect(row.eventTagId == "seed-v1-tag")
            #expect(row.repeatingStart == 2200)
            #expect(row.repeatingOption == "seed-v1-option")
            #expect(row.repeatingEnd == 3300)
            #expect(row.notificationOptions == "seed-v1-notification")
            #expect(row.repeatingEndCount == 44)
            #expect(row.repeatingTurn == nil)
            #expect(version == 6)
        }
    }

    // 6→7 만 태우면 PendingDoneTodoEvent 가 선언 순서로 재생성되고 repeating_turn 이 더해진다
    @Test func runDBMigration_v6ToV7_rebuildsPendingDoneTodos() async throws {
        // given
        try await withMigrationDB(at: mainDBPath, userVersion: 6, seed: { db in
            try db.createTableOrNot(PendingDoneTodoEventTableV1.self)
            try db.insert(
                PendingDoneTodoEventTableV1.self,
                entities: self.dummyPendingDoneTodos.map { PendingDoneTodoEventTableV1.Entity($0) },
                shouldReplace: true
            )
        }) { mainDB, pool in
            // when
            try await self.makeMigration(mainDB: mainDB, pool: pool, dbVersion: 7).runDBMigration()

            // then
            try await self.requireSelectSucceeds(
                mainDB,
                "SELECT repeating_count, repeating_turn FROM PendingDoneTodoEvent;"
            )
            await #expect(throws: (any Error).self) {
                try await self.requireSelectSucceeds(mainDB, "SELECT uuid FROM PendingDoneTodoEvent_v6;")
            }
            let loaded = try await self.loadPendingDoneTodos(mainDB)
            let version = try await self.loadUserVersion(mainDB)
            let allDayRow = try #require(loaded.first { $0.uuid == "seed-pending" }).asTodoEvent()
            let periodRow = try #require(loaded.first { $0.uuid == "seed-pending-2" }).asTodoEvent()
            #expect(loaded.count == 2)
            #expect(allDayRow.name == "seed-pending-name")
            #expect(allDayRow.creatTimeStamp == 1100)
            #expect(allDayRow.eventTagId == EventTagId("seed-pending-tag"))
            #expect(allDayRow.time == .allDay(5500..<5600, secondsFromGMT: 32400))
            #expect(allDayRow.notificationOptions == [.before(seconds: 300)])
            #expect(allDayRow.repeating?.repeatingStartTime == 2200)
            #expect(allDayRow.repeating?.repeatingEndOption?.endCount == 44)
            #expect(periodRow.creatTimeStamp == 9900)
            #expect(periodRow.time == .period(7700..<7800))
            #expect(periodRow.repeating?.repeatingStartTime == 3300)
            #expect(periodRow.repeating?.repeatingEndOption?.endTime == 8800)
            #expect(version == 7)
        }
    }
}


// MARK: - Test Doubles

private final class FailingExternalCalendarSQLiteConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {
    func hasConnection(serviceId: String) async -> Bool { return false }
    func connection(serviceId: String) async throws -> SQLiteService {
        throw RuntimeError("no connection available")
    }
}
