//
//  TemporaryUserDataMigrationRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import SQLiteService


public final class TemporaryUserDataMigrationRepositoryImple: TemporaryUserDataMigrationRepository, @unchecked Sendable {
    
    private let tempUserDBPath: String
    private let remoteAPI: any RemoteAPI
    private let syncTimeLocalStorage: any EventSyncTimestampLocalStorage
    
    public init(
        tempUserDBPath: String,
        remoteAPI: any RemoteAPI,
        syncTimeLocalStorage: any EventSyncTimestampLocalStorage
    ) {
        self.tempUserDBPath = tempUserDBPath
        self.remoteAPI = remoteAPI
        self.syncTimeLocalStorage = syncTimeLocalStorage
    }
}

extension TemporaryUserDataMigrationRepositoryImple {
    
    private func prepareTempDBsqliteService() async throws -> SQLiteService {
        guard FileManager.default.fileExists(atPath: self.tempUserDBPath)
        else { throw RuntimeError("db file not exists") }
        
        let service = SQLiteService()
        try await service.async.open(path: self.tempUserDBPath)
        return service
    }
    
    public func loadMigrationNeedEventCount() async throws -> Int {
    
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        let todoStorage = TodoLocalStorageImple(sqliteService: service)
        let todos = try await todoStorage.loadAllEvents()
        
        let scheduleEventStorage = ScheduleEventLocalStorageImple(sqliteService: service)
        let schedules = try await scheduleEventStorage.loadAllEvents()
                
        return todos.count + schedules.count
    }
}

extension TemporaryUserDataMigrationRepositoryImple {
    
    public func migrateEventTags() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = EventTagLocalStorageImple(sqliteService: service)
        let alltags = try await storage.loadAllTags()
        
        guard !alltags.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.eventTags
        let payload = BatchEventTagPayload(tags: alltags)
        let result : BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        try? await storage.removeAllTags()
        await self.updateTimestampIfNeed(.eventTag, result.syncTimestamp)
    }
    
    public func migrateTodoEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = TodoLocalStorageImple(sqliteService: service)
        let todos = try await storage.loadAllEvents()
        
        guard !todos.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.todos
        let payload = BatchTodoEventPayload(todos: todos)
        let result: BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        try? await storage.removeAll()
        await self.updateTimestampIfNeed(.todo, result.syncTimestamp)
    }
    
    public func migrateScheduleEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = ScheduleEventLocalStorageImple(sqliteService: service)
        let schedules = try await storage.loadAllEvents()
        
        guard !schedules.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.schedules
        let payload = BatchScheduleEventPayload(events: schedules)
        let result: BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        try? await storage.removeAll()
        await updateTimestampIfNeed(.schedule, result.syncTimestamp)
    }
    
    private func updateTimestampIfNeed(_ dataType: SyncDataType, _ timestamp: Int?) async {
        guard let timestamp else { return }
        let serverTimestamp = EventSyncTimestamp(dataType, timestamp)
        try? await self.syncTimeLocalStorage.updateLocalTimestamp(by: serverTimestamp)
    }
    
    public func migrateEventDetails() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = EventDetailDataLocalStorageImple(sqliteService: service)
        let details = try await storage.loadAll()
        
        guard !details.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.eventDetails
        let payload = BatchEventDetailPayload(details: details)
        let _ : BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        try? await storage.removeAll()
    }
    
    public func migrateDoneEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = TodoLocalStorageImple(sqliteService: service)
        let doneEvents = try await storage.loadAllDoneEvents()
        
        guard !doneEvents.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.doneTodos
        let payload = BatchDoneTodoEventPayload(dones: doneEvents)
        let _: BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        try? await storage.removeAllDoneEvents()
    }
    
    public func clearTemporaryUserData() async throws {
        try FileManager.default.removeItem(atPath: self.tempUserDBPath)
    }
}
