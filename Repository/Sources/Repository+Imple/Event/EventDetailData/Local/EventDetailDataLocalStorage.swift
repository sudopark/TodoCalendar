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
    func removeDetail(_ id: String) async throws
    func removeAll() async throws
    func removeDetails(ids: [String]) async throws
}

public final class EventDetailDataLocalStorageImple<Detail: DetailTable>: EventDetailDataLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
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
    
    public func removeDetail(_ id: String) async throws {
        try await self.sqliteService.async.run { db in
            let query = Detail.delete().where { $0.uuid == id }
            try db.delete(Detail.self, query: query)
        }
    }
    
    public func removeAll() async throws {
        try await self.sqliteService.async.run { try $0.dropTable(Detail.self) }
    }
    
    public func removeDetails(ids: [String]) async throws {
        try await self.sqliteService.async.run { db in
            let query = Detail.delete().where { $0.uuid.in(ids) }
            try db.delete(Detail.self, query: query)
        }
    }
}
