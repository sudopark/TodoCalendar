//
//  EventUploadPendingQueueLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 7/22/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
@preconcurrency import SQLiteService
import Domain
import Extensions


public protocol EventUploadPendingQueueLocalStorage: Sendable {
    
    func popTask() async throws -> EventUploadingTask?
    func pushTask(_ task: EventUploadingTask) async throws
    func pushFailedTask(_ tasks: [EventUploadingTask]) async throws
}


public final class EventUploadPendingQueueLocalStorageImple: EventUploadPendingQueueLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Queue = EventUploadPendingQueueTable
}

extension EventUploadPendingQueueLocalStorageImple {
    
    public func popTask() async throws -> EventUploadingTask? {
        try await self.sqliteService.async.run { db in
            let query = Queue.selectAll()
                .where { $0.uploadFailCount < 3 }
                .orderBy(isAscending: true) { $0.timestamp }
            guard let firstTask = try db.loadOne(Queue.self, query: query)
            else { return nil }
            
            let deleteQuery = Queue.delete().where { $0.uuid == firstTask.uuid }
            try db.delete(Queue.self, query: deleteQuery)
            return firstTask
        }
    }
    
    public func pushTask(_ task: EventUploadingTask) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Queue.self, entity: task, shouldReplace: true)
        }
    }
    
    public func pushFailedTask(_ tasks: [EventUploadingTask]) async throws {
        try await self.sqliteService.async.run { db in
            try db.insert(Queue.self, entities: tasks, shouldReplace: true)
        }
    }
}
