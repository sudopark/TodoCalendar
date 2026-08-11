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
    typealias EntityType = PendingDoneTodoEventTable.PendingDoneTodo
    static var tableName: String { PendingDoneTodoEventTable.tableName }

    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        guard let newColumn = PendingDoneTodoEventTable.Columns(rawValue: column.rawValue)
        else { return nil }
        return PendingDoneTodoEventTable.scalar(entity, for: newColumn)
    }
}

extension TodoLocalStorageImpleTests {

    private func saveLegacyPendingDoneTodo(_ origin: TodoEvent) async throws {
        try await self.sqliteService.async.run { db in
            typealias Legacy = PendingDoneTodoEventTableV6LegacyTable
            let pending = PendingDoneTodoEventTable.PendingDoneTodo(todoEvent: origin)
            try db.createTableOrNot(Legacy.self)
            try db.insert(Legacy.self, entities: [pending], shouldReplace: true)

            let state = TodoToggleStateTable.ToggleState(todoId: origin.uuid, state: .completing)
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
