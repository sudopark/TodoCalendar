//
//  SQLiteLocalStorage+Migration.swift
//  Repository
//
//  Created by sudo.park on 3/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain
import Extensions


extension SQLiteService {
    
    public func runMigration(upTo version: Int32) {
        
        self.migrate(
            upto: version,
            steps: self.runMigrationStep(),
            completed: self.logMigrationResult()
        )
    }
    
    public func runMigration(upTo version: Int32) async throws {
        
        do {
            let newVersion = try await self.async.migrate(
                upto: version,
                steps: self.runMigrationStep(),
                finalized: { [weak self] version, database in
                    self?.logMigrationResult()(.success(version))
                    try? self?.updateJournalModeIfNeed(database)
                }
            )
        } catch {
            logMigrationResult()(.failure(error))
        }
    }
    
    private func runMigrationStep() -> (Int32, any DataBase) throws -> Void {
        return { [weak self] version, database in
            switch version {
            case 0:
                try self?.runMigrationVersion0To1(database)
                
            case 1:
                try self?.runMigrationVersion1to2(database)
                
            case 2:
                try self?.runMigrationVersion2to3(database)
                
            case 3:
                try self?.runMigrationVersion3to4(database)
                
            case 4:
                try? self?.runMigrationVersion4to5(database)
                
            default:
                break
            }
        }
    }
    
    private func logMigrationResult() -> (Result<Int32, any Error>) -> Void {
        return { result in
            switch result {
            case .success(let newVersion):
                logger.log(.sql, level: .info, "db migration finished to: \(newVersion)")
            case .failure(let error):
                logger.log(.sql, level: .error, "db migration failed, reason: \(error)")
                
            }
        }
    }
}

extension SQLiteService {
    
    
    func runMigrationVersion0To1(_ database: any DataBase) throws -> Void {
        do {
            try database.migrate(TodoEventTable.self, version: 0)
            logger.log(.sql, level: .info, "migratiob version 0 -> 1, TodoEventTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 0 -> 1 faield.. will drop TodoEventTable")
            try? database.dropTable(TodoEventTable.self)
        }
        do {
            try database.migrate(ScheduleEventTable.self, version: 0)
            logger.log(.sql, level: .info, "migratiob version 0 -> 1, ScheduleEventTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 0 -> 1 faield.. will drop ScheduleEventTable")
            try? database.dropTable(ScheduleEventTable.self)
        }
        do {
            try database.migrate(PendingDoneTodoEventTable.self, version: 0)
            logger.log(.sql, level: .info, "migratiob version 0 -> 1, PendingDoneTodoEventTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 0 -> 1 faield.. will drop PendingDoneTodoEventTable")
            try? database.dropTable(PendingDoneTodoEventTable.self)
        }
    }
    
    func runMigrationVersion1to2(_ database: any DataBase) throws -> Void {
        do {
            try database.migrate(GoogleCalendarEventOriginTable.self, version: 1)
            logger.log(.sql, level: .info, "migratiob version 1 -> 2, GoogleCalendarEventOriginTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 1 -> 2 faield.. will drop GoogleCalendarEventOriginTable")
            try? database.dropTable(GoogleCalendarEventOriginTable.self)
        }
    }
    
    func runMigrationVersion2to3(_ database: any DataBase) throws -> Void {
        do {
            try database.migrate(GoogleCalendarEventTagTable.self, version: 2)
            logger.log(.sql, level: .info, "migratiob version 2 -> 3, GoogleCalendarEventTagTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 2 -> 3 faield.. will drop GoogleCalendarEventTagTable")
            try? database.dropTable(GoogleCalendarEventTagTable.self)
        }
    }
    
    func runMigrationVersion3to4(_ database: any DataBase) throws -> Void {
        do {
            try database.migrate(GoogleCalendarEventOriginTable.self, version: 3)
            logger.log(.sql, level: .info, "migratiob version 3 -> 4, GoogleCalendarEventOriginTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 3 -> 4 faield.. will drop GoogleCalendarEventOriginTable")
            try? database.dropTable(GoogleCalendarEventOriginTable.self)
        }
    }
    
    func runMigrationVersion4to5(_ database: any DataBase) throws {
        do {
            try database.createTableOrNot(EventUploadPendingQueueTableV4TempTable.self)
            try database.migrate(EventUploadPendingQueueTable.self, version: 4)
            logger.log(.sql, level: .info, "migratiob version 4 -> 5, EventUploadPendingQueueTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 4 -> 5 faield.. will drop EventUploadPendingQueueTable")
            try? database.dropTable(EventUploadPendingQueueTable.self)
        }
    }
    
    private func updateJournalModeIfNeed(_ database: any DataBase) throws {
        do {
            let mode = (try database.journalMode()).uppercased()
            logger.log(.sql, level: .info, "current journal mode: \(mode)")
            guard mode != "WAL" else { return }
            
            try database.updateJournalMode("WAL")
            logger.log(.sql, level: .info, "update journal mode to WAL")
        } catch {
            logger.log(.sql, level: .error, "fail to update journal mode")
        }
    }
}

extension SQLiteService {
    
    public func prepareTables() async throws {
        
        try await self.async.run { db in
            
            try? db.createTableOrNot(KeyValueTable.self)
            try? db.createTableOrNot(HolidayRepositoryImple.HolidayTable.self)
            try? db.createTableOrNot(EventTimeTable.self)
            try? db.createTableOrNot(EventDetailDataTable.self)
            try? db.createTableOrNot(CustomEventTagTable.self)
            try? db.createTableOrNot(GoogleCalendarEventTagTable.self)
            try? db.createTableOrNot(GoogleCalendarColorsTable.self)
            try? db.createTableOrNot(GoogleCalendarEventOriginTable.self)
            try? db.createTableOrNot(ScheduleEventTable.self)
            try? db.createTableOrNot(EventSyncTimestampTable.self)
            try? db.createTableOrNot(DoneTodoEventTable.self)
            try? db.createTableOrNot(DoneTodoEventDetailTable.self)
            try? db.createTableOrNot(PendingDoneTodoEventTable.self)
            try? db.createTableOrNot(TodoEventTable.self)
            try? db.createTableOrNot(TodoToggleStateTable.self)
            try? db.createTableOrNot(EventUploadPendingQueueTable.self)
            try? db.createTableOrNot(EventNotificationIdTable.self)
            
        }
    }
}
