//
//  EventDetailDataLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 10/28/23.
//

import Foundation
@preconcurrency import SQLiteService
import Domain


public protocol EventDetailDataLocalStorage: Sendable {
    func loadAll() async throws -> [EventDetailData]
    func loadDetail(_ id: String) async throws -> EventDetailData?
    func saveDetail(_ detail: EventDetailData) async throws
    func saveDetails(_ details: [EventDetailData]) async throws
    func removeDetail(_ id: String) async throws
    func removeAll() async throws
}

public final class EventDetailDataLocalStorageImple: EventDetailDataLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Detail = EventDetailDataTable
}


extension EventDetailDataLocalStorageImple {
    
    public func loadAll() async throws -> [EventDetailData] {
        let query = Detail.selectAll()
        return try await self.sqliteService.async.run { try $0.load(query) }
    }
    
    public func loadDetail(_ id: String) async throws -> EventDetailData? {
        let query = Detail.selectAll { $0.uuid == id }
        return try await self.sqliteService.async.run {
            return try $0.loadOne(query)
        }
    }
    
    public func saveDetail(_ detail: EventDetailData) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Detail.self, entity: detail, shouldReplace: true)
        }
    }
    
    public func saveDetails(_ details: [EventDetailData]) async throws {
        try await self.sqliteService.async.run { db in
            try db.insert(Detail.self, entities: details, shouldReplace: true)
        }
    }
    
    public func removeDetail(_ id: String) async throws {
        try await self.sqliteService.async.run { db in
            let query = Detail.delete().where { $0.uuid == id }
            try db.delete(Detail.self, query: query)
        }
    }
    
    public func removeAll() async throws {
        try await self.sqliteService.async.run { try $0.dropTable(Detail.self) }
    }
}
