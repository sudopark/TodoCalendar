//
//  EventDetailDataLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 10/28/23.
//

import Foundation
@preconcurrency import SQLiteService
import Domain


public final class EventDetailDataLocalStorage: Sendable {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Detail = EventDetailDataTable
}


extension EventDetailDataLocalStorage {
    
    func loadDetail(_ id: String) async throws -> EventDetailData? {
        let query = Detail.selectAll { $0.uuid == id }
        return try await self.sqliteService.async.run {
            return try $0.loadOne(query)
        }
    }
    
    func saveDetail(_ detail: EventDetailData) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Detail.self, entity: detail, shouldReplace: true)
        }
    }
    
    func removeDetail(_ id: String) async throws {
        try await self.sqliteService.async.run { db in
            let query = Detail.delete().where { $0.uuid == id }
            try db.delete(Detail.self, query: query)
        }
    }
}
