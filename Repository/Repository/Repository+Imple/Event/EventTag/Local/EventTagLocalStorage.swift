//
//  EventTagLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
import SQLiteService
import Domain

public final class EventTagLocalStorage: Sendable {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Tags = EventTagTable
}


extension EventTagLocalStorage {
    
    func saveTag(_ tag: EventTag) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Tags.self, entity: tag, shouldReplace: true)
        }
    }
    
    func editTag(_ tag: EventTag) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Tags.self, entity: tag, shouldReplace: true)
        }
    }
    
    func updateTags(_ tags: [EventTag]) async throws {
        try await self.sqliteService.async.run { db in
            try db.insert(Tags.self, entities: tags)
        }
    }
    
    func loadTag(match name: String) async throws -> [EventTag] {
        let query = Tags.selectAll { $0.name == name }
        return try await self.sqliteService.async.run { try $0.load(query) }
    }
    
    func loadTags(in ids: [String]) async throws -> [EventTag] {
        let query = Tags.selectAll { $0.uuid.in(ids) }
        return try await self.sqliteService.async.run { db in
            return try db.load(Tags.self, query: query)
        }
    }
}
