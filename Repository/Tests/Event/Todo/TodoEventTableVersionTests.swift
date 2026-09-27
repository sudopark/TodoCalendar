//
//  TodoEventTableVersionTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 9/27/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import SQLiteService

@testable import Repository


@Suite("TodoEventTableVersionTests", .serialized)
final class TodoEventTableVersionTests: LocalTestable {
    
    let sqliteService: SQLiteService = .init()
    
    private var dummyCurrentEntity: TodoEventTable.Entity {
        return TodoEventTable.Entity(
            uuid: "v0-migrated",
            name: "migrated",
            createTimeStamp: 1100,
            eventTagId: "tag-1",
            repeatingStart: 2200,
            repeatingOption: "option-text",
            repeatingEnd: 3300,
            notificationOptions: "notification-text",
            repeatingEndCount: 44,
            repeatingTurn: 55
        )
    }
    
    private var dummyV1Entity: TodoEventTableV1.Entity {
        return TodoEventTableV1.Entity(
            uuid: "v0-to-v1",
            name: "half-migrated",
            createTimeStamp: 1100,
            eventTagId: "tag-1",
            repeatingStart: 2200,
            repeatingOption: "option-text",
            repeatingEnd: 3300,
            notificationOptions: "notification-text",
            repeatingEndCount: 44
        )
    }
}


// MARK: - V0 에서 두 스텝을 태우면 현재 선언과 맞는다

extension TodoEventTableVersionTests {
    
    @Test func versionDeclarations_migrateFromV0_matchCurrentSchema() async throws {
        try await self.runTestWithOpenClose("todo_table_version_1") {
            // given
            let entity = self.dummyCurrentEntity
            
            // when
            try await self.sqliteService.async.run { db in
                try db.createTableOrNot(TodoEventTableV0.self)
                try db.migrate(TodoEventTable.self, version: 0)
                try db.migrate(TodoEventTable.self, version: 5)
                try db.insert(TodoEventTable.self, entities: [entity], shouldReplace: true)
            }
            let loaded = try await self.sqliteService.async.run([TodoEventTable.Entity].self) { db in
                try db.load(TodoEventTable.self, query: TodoEventTable.selectAll())
            }
            
            // then
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.uuid == "v0-migrated")
            #expect(row.name == "migrated")
            #expect(row.createTimeStamp == 1100)
            #expect(row.eventTagId == "tag-1")
            #expect(row.repeatingStart == 2200)
            #expect(row.repeatingOption == "option-text")
            #expect(row.repeatingEnd == 3300)
            #expect(row.notificationOptions == "notification-text")
            #expect(row.repeatingEndCount == 44)
            #expect(row.repeatingTurn == 55)
        }
    }
}


// MARK: - V0 에서 한 스텝만 태우면 V1 선언과 맞는다

extension TodoEventTableVersionTests {
    
    @Test func versionDeclarations_v1MatchesMigrationFromV0() async throws {
        try await self.runTestWithOpenClose("todo_table_version_2") {
            // given
            let entity = self.dummyV1Entity
            
            // when
            try await self.sqliteService.async.run { db in
                try db.createTableOrNot(TodoEventTableV0.self)
                try db.migrate(TodoEventTable.self, version: 0)
                try db.insert(TodoEventTableV1.self, entities: [entity], shouldReplace: true)
            }
            let loaded = try await self.sqliteService.async.run([TodoEventTableV1.Entity].self) { db in
                try db.load(TodoEventTableV1.self, query: TodoEventTableV1.selectAll())
            }
            
            // then
            let row = try #require(loaded.first)
            #expect(loaded.count == 1)
            #expect(row.uuid == "v0-to-v1")
            #expect(row.name == "half-migrated")
            #expect(row.createTimeStamp == 1100)
            #expect(row.eventTagId == "tag-1")
            #expect(row.repeatingStart == 2200)
            #expect(row.repeatingOption == "option-text")
            #expect(row.repeatingEnd == 3300)
            #expect(row.notificationOptions == "notification-text")
            #expect(row.repeatingEndCount == 44)
        }
    }
}
