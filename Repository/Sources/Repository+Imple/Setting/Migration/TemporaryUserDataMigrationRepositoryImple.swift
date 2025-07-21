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
    private let eventTagLocalStorage: any EventTagLocalStorage
    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleLocalStorage: any ScheduleEventLocalStorage
    private let eventDetailLocalStorage: any EventDetailDataLocalStorage
    private let syncTimeLocalStorage: any EventSyncTimestampLocalStorage
    
    public init(
        tempUserDBPath: String,
        remoteAPI: any RemoteAPI,
        eventTagLocalStorage: any EventTagLocalStorage,
        todoLocalStorage: any TodoLocalStorage,
        scheduleLocalStorage: any ScheduleEventLocalStorage,
        eventDetailLocalStorage: any EventDetailDataLocalStorage,
        syncTimeLocalStorage: any EventSyncTimestampLocalStorage
    ) {
        self.tempUserDBPath = tempUserDBPath
        self.remoteAPI = remoteAPI
        self.eventTagLocalStorage = eventTagLocalStorage
        self.todoLocalStorage = todoLocalStorage
        self.scheduleLocalStorage = scheduleLocalStorage
        self.eventDetailLocalStorage = eventDetailLocalStorage
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
        
        let tempStorage = EventTagLocalStorageImple(sqliteService: service)
        let alltags = try await tempStorage.loadAllTags()
        
        guard !alltags.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.eventTags
        let payload = BatchEventTagPayload(tags: alltags)
        let result : BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        try? await tempStorage.removeAllTags()
        do {
            try await eventTagLocalStorage.updateTags(alltags)
            await self.updateTimestampIfNeed(.eventTag, result.syncTimestamp)
        } catch let error {
            throw error
        }
    }
    
    public func migrateTodoEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let tempStorage = TodoLocalStorageImple(sqliteService: service)
        let todos = try await tempStorage.loadAllEvents()
        
        guard !todos.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.todos
        let payload = BatchTodoEventPayload(todos: todos)
        let result: BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        try? await tempStorage.removeAll()
        do {
            try await todoLocalStorage.updateTodoEvents(todos)
            await self.updateTimestampIfNeed(.todo, result.syncTimestamp)
        } catch let error {
            throw error
        }
    }
    
    public func migrateScheduleEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let tempSorage = ScheduleEventLocalStorageImple(sqliteService: service)
        let schedules = try await tempSorage.loadAllEvents()
        
        guard !schedules.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.schedules
        let payload = BatchScheduleEventPayload(events: schedules)
        let result: BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        try? await tempSorage.removeAll()
        do {
            try await self.scheduleLocalStorage.updateScheduleEvents(schedules)
            await updateTimestampIfNeed(.schedule, result.syncTimestamp)
        } catch let error {
            throw error
        }
    }
    
    private func updateTimestampIfNeed(_ dataType: SyncDataType, _ timestamp: Int?) async {
        guard let timestamp else { return }
        let serverTimestamp = EventSyncTimestamp(dataType, timestamp)
        try? await self.syncTimeLocalStorage.updateLocalTimestamp(by: serverTimestamp)
    }
    
    public func migrateEventDetails() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let tempStorage = EventDetailDataLocalStorageImple(sqliteService: service)
        let details = try await tempStorage.loadAll()
        
        guard !details.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.eventDetails
        let payload = BatchEventDetailPayload(details: details)
        let _ : BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        try? await tempStorage.removeAll()
        try await self.eventDetailLocalStorage.saveDetails(details)
    }
    
    public func migrateDoneEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let tempStorage = TodoLocalStorageImple(sqliteService: service)
        let doneEvents = try await tempStorage.loadAllDoneEvents()
        
        guard !doneEvents.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.doneTodos
        let payload = BatchDoneTodoEventPayload(dones: doneEvents)
        let _: BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        try? await tempStorage.removeAllDoneEvents()
        try await self.todoLocalStorage.updateDoneTodos(doneEvents)
    }
    
    public func clearTemporaryUserData() async throws {
        try FileManager.default.removeItem(atPath: self.tempUserDBPath)
    }
}
