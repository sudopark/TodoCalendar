//
//  EventSyncTimestampLocalStorage.swift
//  RepositoryTests
//
//  Created by sudo.park on 7/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain


public protocol EventSyncTimestampLocalStorage: Sendable {
    
    func loadLocalTimestamp(for dataType: SyncDataType) async throws -> EventSyncTimestamp?
    
    func updateLocalTimestamp(by serverTimestamp: EventSyncTimestamp) async throws
}


public final class EventSyncTimestampLocalStorageImple: EventSyncTimestampLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias SyncTimeStamp = EventSyncTimestampTable
}


extension EventSyncTimestampLocalStorageImple {
    
    public func loadLocalTimestamp(
        for dataType: SyncDataType
    ) async throws -> EventSyncTimestamp? {
        return try await self.sqliteService.async.run { db in
            let query = SyncTimeStamp.selectAll { $0.dataType == dataType.rawValue }
            return try db.loadOne(query)
        }
    }
    
    public func updateLocalTimestamp(
        by serverTimestamp: EventSyncTimestamp
    ) async throws {
        return try await self.sqliteService.async.run { db in
            try db.insert(
                SyncTimeStamp.self, entities: [serverTimestamp],
                shouldReplace: true
            )
        }
    }
}
