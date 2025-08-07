//
//  EventTagLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
@preconcurrency import SQLiteService
import Domain


public protocol EventTagLocalStorage: Sendable {
    func saveTag(_ tag: CustomEventTag) async throws
    func editTag(_ uuid: String, with params: CustomEventTagEditParams) async throws
    func updateTags(_ tags: [CustomEventTag]) async throws
    func deleteTags(_ tagIds: [String]) async throws
    func loadTag(match name: String) async throws -> [CustomEventTag]
    func loadTags(in ids: [String]) async throws -> [CustomEventTag]
    func loadAllTags() async throws -> [CustomEventTag]
    func removeAllTags() async throws
}
extension EventTagLocalStorage {
    
    func deleteTag(_ tagId: String) async throws {
        return try await deleteTags([tagId])
    }
    
    func loadTag(_ id: String) async throws -> CustomEventTag? {
        return try await self.loadTags(in: [id]).first
    }
}

public final class EventTagLocalStorageImple: EventTagLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Tags = CustomEventTagTable
}


extension EventTagLocalStorageImple {
    
    public func saveTag(_ tag: CustomEventTag) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Tags.self, entity: tag, shouldReplace: true)
        }
    }
    
    public func editTag(_ uuid: String, with params: CustomEventTagEditParams) async throws {
        try await self.sqliteService.async.run { db in
            let query = Tags.update {[
                $0.name == params.name,
                $0.colorHex == params.colorHex
            ]}
            .where { $0.uuid == uuid }
            try db.update(Tags.self, query: query)
        }
    }
    
    public func updateTags(_ tags: [CustomEventTag]) async throws {
        try await self.sqliteService.async.run { db in
            try db.insert(Tags.self, entities: tags)
        }
    }
    
    public func deleteTags(_ tagIds: [String]) async throws {
        try await self.sqliteService.async.run { db in
            let deleteQuery = Tags.delete().where { $0.uuid.in(tagIds) }
            try db.delete(Tags.self, query: deleteQuery)
        }
    }
    
    public func loadTag(match name: String) async throws -> [CustomEventTag] {
        let query = Tags.selectAll { $0.name == name }
        return try await self.sqliteService.async.run { try $0.load(query) }
    }
    
    public func loadTags(in ids: [String]) async throws -> [CustomEventTag] {
        let query = Tags.selectAll { $0.uuid.in(ids) }
        return try await self.sqliteService.async.run { db in
            return try db.load(Tags.self, query: query)
        }
    }
    
    public func loadAllTags() async throws -> [CustomEventTag] {
        let query = Tags.selectAll()
        return try await self.sqliteService.async.run { db in
            return try db.load(Tags.self, query: query)
        }
    }
    
    public func removeAllTags() async throws {
        try await self.sqliteService.async.run { try $0.dropTable(Tags.self) } 
    }
}
