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
                finalized: { [weak self] version, _ in
                    self?.logMigrationResult()(.success(version))
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
                
            default:
                break
            }
        }
    }
    
    private func logMigrationResult() -> (Result<Int32, any Error>) -> Void {
        return { result in
            switch result {
            case .success(let newVersion):
                logger.log(level: .info, "db migration finished to: \(newVersion)")
            case .failure(let error):
                logger.log(level: .error, "db migration failed, reason: \(error)")
                
            }
        }
    }
}

extension SQLiteService {
    
    
    func runMigrationVersion0To1(_ database: any DataBase) throws -> Void {
        do {
            try database.migrate(TodoEventTable.self, version: 0)
            logger.log(level: .info, "migratiob version 0 -> 1, TodoEventTable finished")
        } catch {
            logger.log(level: .error, "migration version 0 -> 1 faield.. will drop TodoEventTable")
            try? database.dropTable(TodoEventTable.self)
        }
        do {
            try database.migrate(ScheduleEventTable.self, version: 0)
            logger.log(level: .info, "migratiob version 0 -> 1, ScheduleEventTable finished")
        } catch {
            logger.log(level: .error, "migration version 0 -> 1 faield.. will drop ScheduleEventTable")
            try? database.dropTable(ScheduleEventTable.self)
        }
        do {
            try database.migrate(PendingDoneTodoEventTable.self, version: 0)
            logger.log(level: .info, "migratiob version 0 -> 1, PendingDoneTodoEventTable finished")
        } catch {
            logger.log(level: .error, "migration version 0 -> 1 faield.. will drop PendingDoneTodoEventTable")
            try? database.dropTable(PendingDoneTodoEventTable.self)
        }
    }
    
    func runMigrationVersion1to2(_ database: any DataBase) throws -> Void {
        do {
            try database.migrate(GoogleCalendarEventOriginTable.self, version: 1)
            logger.log(level: .info, "migratiob version 1 -> 2, GoogleCalendarEventOriginTable finished")
        } catch {
            logger.log(level: .error, "migration version 1 -> 2 faield.. will drop GoogleCalendarEventOriginTable")
            try? database.dropTable(GoogleCalendarEventOriginTable.self)
        }
    }
    
    func runMigrationVersion2to3(_ database: any DataBase) throws -> Void {
        do {
            try database.migrate(GoogleCalendarEventTagTable.self, version: 2)
            logger.log(level: .info, "migratiob version 2 -> 3, GoogleCalendarEventTagTable finished")
        } catch {
            logger.log(level: .error, "migration version 2 -> 3 faield.. will drop GoogleCalendarEventOriginTable")
            try? database.dropTable(GoogleCalendarEventOriginTable.self)
        }
    }
}
