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
    func saveTag(_ tag: EventTag) async throws
    func editTag(_ uuid: String, with params: EventTagEditParams) async throws
    func updateTags(_ tags: [EventTag]) async throws
    func deleteTags(_ tagIds: [String]) async throws
    func loadTag(match name: String) async throws -> [EventTag]
    func loadTags(in ids: [String]) async throws -> [EventTag]
    func loadAllTags() async throws -> [EventTag]
}
extension EventTagLocalStorage {
    
    func deleteTag(_ tagId: String) async throws {
        return try await deleteTags([tagId])
    }
}

public final class EventTagLocalStorageImple: EventTagLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Tags = EventTagTable
}


extension EventTagLocalStorageImple {
    
    public func saveTag(_ tag: EventTag) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Tags.self, entity: tag, shouldReplace: true)
        }
    }
    
    public func editTag(_ uuid: String, with params: EventTagEditParams) async throws {
        try await self.sqliteService.async.run { db in
            let query = Tags.update {[
                $0.name == params.name,
                $0.colorHex == params.colorHex
            ]}
            .where { $0.uuid == uuid }
            try db.update(Tags.self, query: query)
        }
    }
    
    public func updateTags(_ tags: [EventTag]) async throws {
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
    
    public func loadTag(match name: String) async throws -> [EventTag] {
        let query = Tags.selectAll { $0.name == name }
        return try await self.sqliteService.async.run { try $0.load(query) }
    }
    
    public func loadTags(in ids: [String]) async throws -> [EventTag] {
        let query = Tags.selectAll { $0.uuid.in(ids) }
        return try await self.sqliteService.async.run { db in
            return try db.load(Tags.self, query: query)
        }
    }
    
    public func loadAllTags() async throws -> [EventTag] {
        let query = Tags.selectAll()
        return try await self.sqliteService.async.run { db in
            return try db.load(Tags.self, query: query)
        }
    }
}
