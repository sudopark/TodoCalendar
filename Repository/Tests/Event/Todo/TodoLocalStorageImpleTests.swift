//
//  TodoLocalStorageImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import SQLiteService
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


@Suite("TodoLocalStorageImpleTests", .serialized)
final class TodoLocalStorageImpleTests: LocalTestable {

    let sqliteService: SQLiteService = .init()

    private func makeStorage() -> TodoLocalStorageImple {
        return TodoLocalStorageImple(sqliteService: self.sqliteService)
    }

    private var dummyRepeatingTodo: TodoEvent {
        let option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
        let repeating = EventRepeating(repeatingStartTime: 100, repeatOption: option)
            |> \.repeatingEndOption .~ .count(10)
        return TodoEvent(uuid: "repeating", name: "some")
            |> \.eventTagId .~ .custom("tag")
            |> \.time .~ .at(300)
            |> \.repeating .~ pure(repeating)
            |> \.repeatingTurn .~ 3
            |> \.notificationOptions .~ [.atTime]
    }

    private var dummyUntilRepeatingTodo: TodoEvent {
        let option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
        let repeating = EventRepeating(repeatingStartTime: 100, repeatOption: option)
            |> \.repeatingEndOption .~ .until(4000)
        return TodoEvent(uuid: "until-repeating", name: "some")
            |> \.creatTimeStamp .~ 2500
            |> \.eventTagId .~ .custom("tag")
            |> \.time .~ .at(300)
            |> \.repeating .~ pure(repeating)
            |> \.repeatingTurn .~ 7
            |> \.notificationOptions .~ [.atTime, .before(seconds: 600)]
    }

    private func dummyDoneTodo(
        uuid: String = "done-uuid",
        tag: EventTagId? = .custom("tag-id")
    ) -> DoneTodoEvent {
        return DoneTodoEvent(
            uuid: uuid,
            name: "done todo name",
            originEventId: "origin-todo-id",
            doneTime: Date(timeIntervalSince1970: 7700)
        )
        |> \.eventTagId .~ tag
        |> \.eventTime .~ .period(5500..<5600)
        |> \.notificationOptions .~ [.atTime, .before(seconds: 600), .allDay9AM]
    }

    private func dummyPendingRepeating(_ endOption: EventRepeating.RepeatEndOption) -> EventRepeating {
        var option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
        option.interval = 2
        option.dayOfWeeks = [.monday, .friday]
        return EventRepeating(repeatingStartTime: 2200, repeatOption: option)
            |> \.repeatingEndOption .~ endOption
    }

    private func dummyPendingTodo(
        uuid: String = "pending-todo",
        tag: EventTagId? = .custom("tag-id"),
        time: EventTime = .period(5500..<5600),
        endOption: EventRepeating.RepeatEndOption = .until(3300)
    ) -> TodoEvent {
        return TodoEvent(uuid: uuid, name: "pending todo name")
            |> \.creatTimeStamp .~ 1100
            |> \.eventTagId .~ tag
            |> \.time .~ time
            |> \.repeating .~ pure(self.dummyPendingRepeating(endOption))
            |> \.repeatingTurn .~ 55
            |> \.notificationOptions .~ [.atTime, .before(seconds: 600)]
    }

    private func dummyToggleTodo(_ uuid: String) -> TodoEvent {
        return TodoEvent(uuid: uuid, name: "name of \(uuid)")
            |> \.creatTimeStamp .~ 1100
            |> \.time .~ .at(5500)
    }

    private func loadPendingOrigin(
        _ storage: TodoLocalStorageImple, _ uuid: String
    ) async throws -> TodoEvent? {
        let state = try await storage.todoToggleState(uuid)
        guard case .completing(let origin, _) = state else { return nil }
        return origin
    }
}


// MARK: - 반복 종료 옵션 왕복

extension TodoLocalStorageImpleTests {

    @Test func storage_whenSaveTodoWithUntilRepeating_loadRestoresUntilOption() async throws {
        try await self.runTestWithOpenClose("todo-until-repeating") {
            // given
            let storage = self.makeStorage()
            let origin = self.dummyUntilRepeatingTodo

            // when
            try await storage.saveTodoEvent(origin)
            let restored = try await storage.loadTodoEvent(origin.uuid)

            // then
            #expect(restored.repeating?.repeatingEndOption == .until(4000))
            #expect(restored.repeating?.repeatingStartTime == 100)
            #expect(restored.repeatingTurn == 7)
            #expect(restored.creatTimeStamp == 2500)
            #expect(restored.notificationOptions == [.atTime, .before(seconds: 600)])
        }
    }
}


// MARK: - 완료 처리 중(completing) 원본 보관

extension TodoLocalStorageImpleTests {

    private func saveCompletingState(
        _ storage: TodoLocalStorageImple, _ origin: TodoEvent
    ) async throws {
        try await storage.saveTodoEvent(origin)
        try await storage.updateTodoToggleState(origin.uuid, .completing(origin: origin))
        try await storage.saveDoneTodoEvent(DoneTodoEvent(origin))
    }

    @Test func storage_whenCompleting_keepRepeatingTodoOriginWithTimeAndTurn() async throws {
        try await self.runTestWithOpenClose("toggle-completing") {
            // given
            let storage = self.makeStorage()
            let origin = self.dummyRepeatingTodo

            // when
            try await self.saveCompletingState(storage, origin)
            let state = try await storage.todoToggleState(origin.uuid)

            // then
            guard case .completing(let restored, _) = state
            else {
                Issue.record("completing 상태가 아님: \(state)")
                return
            }
            #expect(restored.time == .at(300))
            #expect(restored.repeatingTurn == 3)
            #expect(restored.repeating?.repeatingEndOption == .count(10))
        }
    }
}


// MARK: - 완료한 Todo 저장

extension TodoLocalStorageImpleTests {

    @Test func storage_whenSaveDoneTodo_loadRestoresEveryColumn() async throws {
        try await self.runTestWithOpenClose("done-table-every-column") {
            // given
            let storage = self.makeStorage()
            let origin = self.dummyDoneTodo()

            // when
            try await storage.saveDoneTodoEvent(origin)
            let restored = try await storage.loadDoneTodoEvent(doneEventId: "done-uuid")

            // then
            #expect(restored.uuid == "done-uuid")
            #expect(restored.originEventId == "origin-todo-id")
            #expect(restored.name == "done todo name")
            #expect(restored.doneTime == Date(timeIntervalSince1970: 7700))
            #expect(restored.eventTagId == .custom("tag-id"))
            #expect(restored.notificationOptions == [.atTime, .before(seconds: 600), .allDay9AM])
            #expect(restored.eventTime == .period(5500..<5600))
        }
    }

    @Test func storage_whenSaveDoneTodosWithEveryTagKind_loadRestoresSameTagId() async throws {
        try await self.runTestWithOpenClose("done-table-every-tag-kind") {
            // given
            let storage = self.makeStorage()
            let tags: [EventTagId] = [
                .holiday,
                .default,
                .custom("custom-tag"),
                .externalCalendar(serviceId: "google", id: "calendar-id")
            ]
            let origins = tags.enumerated().map { offset, tag in
                self.dummyDoneTodo(uuid: "done-\(offset)", tag: tag)
            }

            // when
            for origin in origins {
                try await storage.saveDoneTodoEvent(origin)
            }
            var restoredTags: [EventTagId?] = []
            for origin in origins {
                let restored = try await storage.loadDoneTodoEvent(doneEventId: origin.uuid)
                restoredTags.append(restored.eventTagId)
            }

            // then
            #expect(restoredTags == [
                .holiday,
                .default,
                .custom("custom-tag"),
                .externalCalendar(serviceId: "google", id: "calendar-id")
            ])
        }
    }
}


// MARK: - 완료 처리 중(completing) 원본의 컬럼 보관

extension TodoLocalStorageImpleTests {

    @Test func storage_whenCompleting_loadRestoresEveryPendingOriginColumn() async throws {
        try await self.runTestWithOpenClose("pending-table-every-column") {
            // given
            let storage = self.makeStorage()
            let origin = self.dummyPendingTodo()

            // when
            try await storage.updateTodoToggleState("pending-todo", .completing(origin: origin))
            let restored = try #require(await self.loadPendingOrigin(storage, "pending-todo"))

            // then
            #expect(restored.uuid == "pending-todo")
            #expect(restored.name == "pending todo name")
            #expect(restored.creatTimeStamp == 1100)
            #expect(restored.eventTagId == .custom("tag-id"))
            #expect(restored.repeating == self.dummyPendingRepeating(.until(3300)))
            #expect(restored.repeating?.repeatingStartTime == 2200)
            #expect(restored.repeating?.repeatingEndOption == .until(3300))
            #expect(restored.notificationOptions == [.atTime, .before(seconds: 600)])
            #expect(restored.repeatingTurn == 55)
            #expect(restored.time == .period(5500..<5600))
        }
    }

    @Test func storage_whenCompletingTodoRepeatsByCount_loadRestoresCountEndOption() async throws {
        try await self.runTestWithOpenClose("pending-table-end-by-count") {
            // given
            let storage = self.makeStorage()
            let origin = self.dummyPendingTodo(endOption: .count(44))

            // when
            try await storage.updateTodoToggleState("pending-todo", .completing(origin: origin))
            let restored = try #require(await self.loadPendingOrigin(storage, "pending-todo"))

            // then
            #expect(restored.repeating?.repeatingEndOption == .count(44))
        }
    }

    @Test func storage_whenCompletingTodoRepeatsUntilTime_loadRestoresUntilEndOption() async throws {
        try await self.runTestWithOpenClose("pending-table-end-by-time") {
            // given
            let storage = self.makeStorage()
            let origin = self.dummyPendingTodo(endOption: .until(3300))

            // when
            try await storage.updateTodoToggleState("pending-todo", .completing(origin: origin))
            let restored = try #require(await self.loadPendingOrigin(storage, "pending-todo"))

            // then
            #expect(restored.repeating?.repeatingEndOption == .until(3300))
        }
    }

    @Test func storage_whenCompletingTodosWithNotCustomTag_loadLeavesTagNil() async throws {
        try await self.runTestWithOpenClose("pending-table-not-custom-tag") {
            // given
            let storage = self.makeStorage()
            let tags: [EventTagId] = [
                .holiday, .default, .externalCalendar(serviceId: "google", id: "calendar-id")
            ]
            let origins = tags.enumerated().map { offset, tag in
                self.dummyPendingTodo(uuid: "pending-\(offset)", tag: tag)
            }

            // when
            for origin in origins {
                try await storage.updateTodoToggleState(origin.uuid, .completing(origin: origin))
            }
            var restoredTags: [EventTagId?] = []
            for origin in origins {
                let restored = try #require(await self.loadPendingOrigin(storage, origin.uuid))
                restoredTags.append(restored.eventTagId)
            }

            // then
            #expect(restoredTags == [nil, nil, nil])
        }
    }

    @Test func storage_whenCompletingTodosWithEveryTimeKind_loadRestoresSameTime() async throws {
        try await self.runTestWithOpenClose("pending-table-every-time-kind") {
            // given
            let storage = self.makeStorage()
            let times: [EventTime] = [
                .at(6600),
                .period(7700..<7800),
                .allDay(8800..<8900, secondsFromGMT: 32400)
            ]
            let origins = times.enumerated().map { offset, time in
                self.dummyPendingTodo(uuid: "pending-\(offset)", time: time)
            }

            // when
            for origin in origins {
                try await storage.updateTodoToggleState(origin.uuid, .completing(origin: origin))
            }
            var restoredTimes: [EventTime?] = []
            for origin in origins {
                let restored = try #require(await self.loadPendingOrigin(storage, origin.uuid))
                restoredTimes.append(restored.time)
            }

            // then
            #expect(restoredTimes == [
                .at(6600),
                .period(7700..<7800),
                .allDay(8800..<8900, secondsFromGMT: 32400)
            ])
        }
    }
}


// MARK: - Todo 토글 상태 저장

extension TodoLocalStorageImpleTests {

    @Test func storage_whenUpdateToggleState_loadRestoresEachState() async throws {
        try await self.runTestWithOpenClose("toggle-table-every-state") {
            // given
            let storage = self.makeStorage()
            let completingTodo = self.dummyToggleTodo("completing-todo")
            let idleTodo = self.dummyToggleTodo("idle-todo")

            // when
            try await storage.updateTodoToggleState("reverting-todo", .reverting)
            try await storage.updateTodoToggleState(
                "completing-todo", .completing(origin: completingTodo)
            )
            try await storage.saveTodoEvent(idleTodo)
            try await storage.updateTodoToggleState("idle-todo", .completing(origin: idleTodo))
            try await storage.updateTodoToggleState("idle-todo", .idle)

            let revertingState = try await storage.todoToggleState("reverting-todo")
            let completingState = try await storage.todoToggleState("completing-todo")
            let idleState = try await storage.todoToggleState("idle-todo")

            // then
            guard case .reverting = revertingState
            else {
                Issue.record("reverting 상태가 아님: \(revertingState)")
                return
            }
            guard case .completing(let origin, _) = completingState
            else {
                Issue.record("completing 상태가 아님: \(completingState)")
                return
            }
            #expect(origin.uuid == "completing-todo")
            #expect(origin.name == "name of completing-todo")
            guard case .idle(let target) = idleState
            else {
                Issue.record("idle 상태가 아님: \(idleState)")
                return
            }
            #expect(target.uuid == "idle-todo")
        }
    }
}


// MARK: - v6 -> v7 컬럼 순서 교정 마이그레이션

private struct PendingDoneTodoEventTableV6LegacyTable: Table {

    enum Columns: String, TableColumn {
        case uuid
        case name
        case createTimeStamp = "create_timestamp"
        case eventTagId = "tag_id"
        case repeatingStart = "repeating_start"
        case repeatingOption = "repeating_option"
        case repeatingEnd = "repeating_end"
        case notificationOptions = "notification_options"
        case timeType = "time_type"
        case timeLowerBound = "time_lower_bound"
        case timeUpperBound = "time_upper_bound"
        case secondsFromGMT = "seconds_from_gmt"
        case repeatingEndCount = "repeating_count"

        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .createTimeStamp, .repeatingStart, .repeatingEnd: return .real([])
            case .eventTagId, .repeatingOption, .notificationOptions, .timeType: return .text([])
            case .timeLowerBound, .timeUpperBound, .secondsFromGMT: return .real([])
            case .repeatingEndCount: return .integer([])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = PendingDoneTodoEventTableV1.Entity
    static var tableName: String { PendingDoneTodoEventTable.tableName }

    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        guard let newColumn = PendingDoneTodoEventTableV1.Columns(rawValue: column.rawValue)
        else { return nil }
        return PendingDoneTodoEventTableV1.scalar(entity, for: newColumn)
    }
}

extension TodoLocalStorageImpleTests {

    private func saveLegacyPendingDoneTodo(_ origin: TodoEvent) async throws {
        try await self.sqliteService.async.run { db in
            typealias Legacy = PendingDoneTodoEventTableV6LegacyTable
            let pending = PendingDoneTodoEventTableV1.Entity(PendingDoneTodoEventTable.Entity(origin))
            try db.createTableOrNot(Legacy.self)
            try db.insert(Legacy.self, entities: [pending], shouldReplace: true)

            let state = TodoToggleStateTable.Entity(todoId: origin.uuid, state: .completing)
            try db.insert(TodoToggleStateTable.self, entities: [state], shouldReplace: true)
        }
    }

    private func migratePendingDoneTodoTable() async throws {
        try await self.sqliteService.async.run { db in
            try db.createTableOrNot(PendingDoneTodoEventTableV6TempTable.self)
            try db.migrate(PendingDoneTodoEventTable.self, version: 6)
        }
    }

    @Test func storage_whenMigrateToVersion7_keepSavedPendingOrigin() async throws {
        try await self.runTestWithOpenClose("toggle-migration") {
            // given
            let storage = self.makeStorage()
            let origin = self.dummyRepeatingTodo
            try await storage.saveTodoEvent(origin)
            try await storage.saveDoneTodoEvent(DoneTodoEvent(origin))
            try await self.saveLegacyPendingDoneTodo(origin)

            // when
            try await self.migratePendingDoneTodoTable()

            // then
            let state = try await storage.todoToggleState(origin.uuid)
            guard case .completing(let restored, _) = state
            else {
                Issue.record("completing 상태가 아님: \(state)")
                return
            }
            #expect(restored.name == "some")
            #expect(restored.eventTagId == .custom("tag"))
            #expect(restored.time == .at(300))
            #expect(restored.repeating?.repeatingEndOption == .count(10))
            #expect(restored.repeatingTurn == nil)
        }
    }
}


// MARK: - 변환이 컬럼을 다 채우는지 (DB 미사용)

extension TodoLocalStorageImpleTests {

    @Test func doneTodoEntity_serialize_leavesNoColumnUnmapped() throws {
        // given
        let done = self.dummyDoneTodo()

        // when
        let values = try DoneTodoEventTable.serialize(entity: .init(done))

        // then
        #expect(values.count == DoneTodoEventTable.Columns.allCases.count)
        #expect(values.isEmpty == false)
        #expect(values.allSatisfy { $0 != nil })
    }

    @Test func toggleStateEntity_serialize_leavesNoColumnUnmapped() throws {
        // given
        let entity = TodoToggleStateTable.Entity(todoId: "todo-id", state: .completing)

        // when
        let values = try TodoToggleStateTable.serialize(entity: entity)

        // then
        #expect(values.count == TodoToggleStateTable.Columns.allCases.count)
        #expect(values.isEmpty == false)
        #expect(values.allSatisfy { $0 != nil })
    }

    @Test func pendingTodoEntity_serialize_leavesNoColumnUnmapped() throws {
        // given
        let todo = self.dummyPendingTodo()

        // when
        let values = try PendingDoneTodoEventTable.serialize(entity: .init(todo))

        // then — 상호 배타인 종료 컬럼 둘은 아래 케이스가 맡는다
        let exclusiveColumns: Set<PendingDoneTodoEventTable.Columns> = [.repeatingEnd, .repeatingEndCount]
        let unmapped = zip(PendingDoneTodoEventTable.Columns.allCases, values)
            .filter { !exclusiveColumns.contains($0.0) && $0.1 == nil }
            .map { $0.0 }
        #expect(values.count == PendingDoneTodoEventTable.Columns.allCases.count)
        #expect(values.isEmpty == false)
        #expect(unmapped.isEmpty)
    }

    @Test func pendingTodoEntity_serializeRepeatingEndedByCount_leavesNoColumnUnmapped() throws {
        // given
        let untilTodo = self.dummyPendingTodo(endOption: .until(3300))
        let countTodo = self.dummyPendingTodo(endOption: .count(44))

        // when
        let untilValues = try PendingDoneTodoEventTable.serialize(entity: .init(untilTodo))
        let countValues = try PendingDoneTodoEventTable.serialize(entity: .init(countTodo))

        // then
        let mapped = zip(untilValues, countValues).map { $0 != nil || $1 != nil }
        #expect(mapped.count == PendingDoneTodoEventTable.Columns.allCases.count)
        #expect(mapped.isEmpty == false)
        #expect(mapped.allSatisfy { $0 })
    }

    @Test func pendingTodoEntity_serializeWithEveryTimeKind_leavesNoColumnUnmapped() throws {
        // given
        let times: [EventTime] = [
            .at(6600),
            .period(7700..<7800),
            .allDay(8800..<8900, secondsFromGMT: 32400)
        ]

        // when
        let rows = try times.map { time -> [String: (any ScalarType)?] in
            let todo = self.dummyPendingTodo(time: time)
            let values = try PendingDoneTodoEventTable.serialize(entity: .init(todo))
            return Dictionary(
                uniqueKeysWithValues: zip(PendingDoneTodoEventTable.Columns.allCases.map { $0.rawValue }, values)
            )
        }

        // then
        let timeColumns = ["time_type", "time_lower_bound", "time_upper_bound", "seconds_from_gmt"]
        let unmapped = rows.map { row in timeColumns.filter { row[$0].flatMap { $0 } == nil } }
        #expect(rows.count == times.count)
        #expect(unmapped.allSatisfy { $0.isEmpty })
        #expect(rows.map { $0["time_type"].flatMap { $0 } as? String } == ["at", "period", "allday"])
        #expect(rows.map { $0["seconds_from_gmt"].flatMap { $0 } as? Double } == [0, 0, 32400])
    }
}
