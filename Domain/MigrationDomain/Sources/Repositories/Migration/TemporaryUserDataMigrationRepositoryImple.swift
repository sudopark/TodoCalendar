//
//  TemporaryUserDataMigrationRepositoryImple.swift
//  MigrationDomain
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions
import SQLiteService
import StorageInfraInterface
import RemoteInfraInterface
import EventDomain
import MigrationDomainInterface
import SettingDomain


public final class TemporaryUserDataMigrationRepositoryImple: TemporaryUserDataMigrationRepository, @unchecked Sendable {
    
    private let tempUserDBPath: String
    private let remoteAPI: any RemoteAPI
    private let environmentStorage: any EnvironmentStorage
    private let accountSqliteService: SQLiteService
    
    public init(
        tempUserDBPath: String,
        remoteAPI: any RemoteAPI,
        environmentStorage: any EnvironmentStorage,
        accountSqliteService: SQLiteService
    ) {
        self.tempUserDBPath = tempUserDBPath
        self.remoteAPI = remoteAPI
        self.environmentStorage = environmentStorage
        self.accountSqliteService = accountSqliteService
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
    
    private func writeIntoAccountDBIgnoringFailure(
        _ dataName: String, _ writing: () async throws -> Void
    ) async {
        do {
            try await writing()
        } catch {
            logger.log(
                .sql, level: .error,
                "temporary user data migration: account db write failed(\(dataName)) => \(error)"
            )
        }
    }
    
    public func loadMigrationNeedEventCount() async throws -> Int {
    
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        let todoStorage = TodoLocalStorageImple(sqliteService: service)
        let todos = try await todoStorage.loadAllEvents()
        
        let scheduleEventStorage = ScheduleEventLocalStorageImple(sqliteService: service)
        let schedules = try await scheduleEventStorage.loadAllEvents()
        
        let themeStorage = CustomColorThemeLocalStorageImple(sqliteService: service)
        let themes = try await themeStorage.fetchThemes()
                
        return todos.count + schedules.count + themes.count
    }
}

extension TemporaryUserDataMigrationRepositoryImple {
    
    public func migrateEventTags() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = EventTagLocalStorageImple(
            sqliteService: service, environmentStorage: self.environmentStorage
        )
        let alltags = try await storage.loadAllTags()
        
        guard !alltags.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.eventTags
        let payload = BatchEventTagPayload(tags: alltags)
        let _ : BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        let accountStorage = EventTagLocalStorageImple(
            sqliteService: self.accountSqliteService, environmentStorage: self.environmentStorage
        )
        await self.writeIntoAccountDBIgnoringFailure("event tags") {
            try await accountStorage.updateTags(alltags)
        }
        
        try? await storage.removeAllTags()
    }
    
    public func migrateTodoEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = TodoLocalStorageImple(sqliteService: service)
        let todos = try await storage.loadAllEvents()
        
        guard !todos.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.todos
        let payload = BatchTodoEventPayload(todos: todos)
        let _: BatchWriteResult = try await self.remoteAPI.request(
            .post, 
            endpoint,
            parameters: payload.asJson()
        )
        let accountStorage = TodoLocalStorageImple(sqliteService: self.accountSqliteService)
        await self.writeIntoAccountDBIgnoringFailure("todo events") {
            try await accountStorage.updateTodoEvents(todos)
        }
        
        try? await storage.removeAll()
    }
    
    public func migrateScheduleEvents() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = ScheduleEventLocalStorageImple(sqliteService: service)
        let schedules = try await storage.loadAllEvents()
        
        guard !schedules.isEmpty else { return}
        
        let endpoint = MigrationEndpoints.schedules
        let payload = BatchScheduleEventPayload(events: schedules)
        let _ : BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        let accountStorage = ScheduleEventLocalStorageImple(sqliteService: self.accountSqliteService)
        await self.writeIntoAccountDBIgnoringFailure("schedule events") {
            try await accountStorage.updateScheduleEvents(schedules)
        }
        
        try? await storage.removeAll()
    }
    
    public func migrateEventDetails() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = EventDetailDataLocalStorageImple<EventDetailDataTable>(sqliteService: service)
        let details = try await storage.loadAll()
        
        guard !details.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.eventDetails
        let payload = BatchEventDetailPayload(details: details)
        let _ : BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        let accountStorage = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: self.accountSqliteService
        )
        await self.writeIntoAccountDBIgnoringFailure("event details") {
            for detail in details {
                try await accountStorage.saveDetail(detail)
            }
        }
        
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
        
        let accountStorage = TodoLocalStorageImple(sqliteService: self.accountSqliteService)
        await self.writeIntoAccountDBIgnoringFailure("done todo events") {
            try await accountStorage.updateDoneTodos(doneEvents)
        }
        
        let detailStorage = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(sqliteService: service)
        let details = try await detailStorage.loadAll()
        if !details.isEmpty {
            
            let detailEndpoint = MigrationEndpoints.doneTodoDetails
            let payload = BatchEventDetailPayload(details: details)
            let _ : BatchWriteResult = try await self.remoteAPI.request(
                .post,
                detailEndpoint,
                parameters: payload.asJson()
            )
            
            let accountDetailStorage = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(
                sqliteService: self.accountSqliteService
            )
            await self.writeIntoAccountDBIgnoringFailure("done todo details") {
                for detail in details {
                    try await accountDetailStorage.saveDetail(detail)
                }
            }
        }
        
        try? await storage.removeAllDoneEvents()
    }
    
    public func migrateCustomColorThemes() async throws {
        let service = try await self.prepareTempDBsqliteService()
        defer { service.close() }
        
        let storage = CustomColorThemeLocalStorageImple(sqliteService: service)
        let themes = try await storage.fetchThemes()
        
        guard !themes.isEmpty else { return }
        
        let endpoint = MigrationEndpoints.customColorThemes
        let payload = BatchCustomColorThemePayload(themes: themes)
        let _: BatchWriteResult = try await self.remoteAPI.request(
            .post,
            endpoint,
            parameters: payload.asJson()
        )
        
        let accountStorage = CustomColorThemeLocalStorageImple(
            sqliteService: self.accountSqliteService
        )
        await self.writeIntoAccountDBIgnoringFailure("custom color themes") {
            for theme in themes {
                try await accountStorage.saveTheme(theme)
            }
        }
        
        try? await storage.removeThemes(themes.map { $0.uuid })
    }
    
    public func clearTemporaryUserData() async throws {
        try FileManager.default.removeItem(atPath: self.tempUserDBPath)
    }
}
