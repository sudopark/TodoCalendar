//
//  AICommandLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 6/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain


public protocol AICommandLocalStorage: AnyObject, Sendable {

    func loadProcessingAICommand() async throws -> ProcessingAICommand?
    func updateProcessingAICommand(_ cmd: ProcessingAICommand) async throws
    func clearProcessingAICommand() async throws
}


public final class AICommandLocalStorageImple: AICommandLocalStorage {

    private let sqliteService: SQLiteService

    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
}


extension AICommandLocalStorageImple {

    public func loadProcessingAICommand() async throws -> ProcessingAICommand? {
        return try await self.sqliteService.async.run { db -> ProcessingAICommand? in
            try? db.createTableOrNot(ProcessingAICommandTable.self)
            let query = ProcessingAICommandTable.selectAll()
            return try db.loadOne(ProcessingAICommandTable.self, query: query)
        }
    }

    public func updateProcessingAICommand(_ cmd: ProcessingAICommand) async throws {
        try await self.sqliteService.async.run { db in
            try? db.createTableOrNot(ProcessingAICommandTable.self)
            try db.delete(ProcessingAICommandTable.self, query: ProcessingAICommandTable.delete())
            try db.insert(ProcessingAICommandTable.self, entities: [cmd])
        }
    }

    public func clearProcessingAICommand() async throws {
        try await self.sqliteService.async.run { db in
            try? db.createTableOrNot(ProcessingAICommandTable.self)
            try db.delete(ProcessingAICommandTable.self, query: ProcessingAICommandTable.delete())
        }
    }
}
