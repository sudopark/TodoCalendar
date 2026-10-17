//
//  ExternalCalendarDBMigrationImple.swift
//  Repository
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService
import Extensions


public final class ExternalCalendarDBMigrationImple: @unchecked Sendable {

    private let googleCalendarDBVersion: Int32
    private let appleCalendarDBVersion: Int32

    public init(googleCalendarDBVersion: Int32, appleCalendarDBVersion: Int32) {
        self.googleCalendarDBVersion = googleCalendarDBVersion
        self.appleCalendarDBVersion = appleCalendarDBVersion
    }

    public func runMigration(serviceId: String, dbService: SQLiteService) async throws {
        switch serviceId {
        case GoogleCalendarService.id: try await self.runGoogleCalendarDBMigration(dbService)
        case AppleCalendarService.id: try await self.runAppleCalendarDBMigration(dbService)
        default: break
        }
    }
}


// MARK: - DB Migration steps

extension ExternalCalendarDBMigrationImple {

    private func runGoogleCalendarDBMigration(_ dbService: SQLiteService) async throws {
        let _ = try await dbService.async.migrate(
            upto: self.googleCalendarDBVersion,
            steps: { [weak self] version, database in
                switch version {
                case 0: try self?.runGoogleCalendarEventTagMigration(version, database)
                default: break
                }
            },
            finalized: { [weak self] version, database in
                self?.finishMigration(serviceId: GoogleCalendarService.id, version, database)
            }
        )
    }

    private func runAppleCalendarDBMigration(_ dbService: SQLiteService) async throws {
        let _ = try await dbService.async.migrate(
            upto: self.appleCalendarDBVersion,
            steps: { version, _ in
                switch version {
                default: break
                }
            },
            finalized: { [weak self] version, database in
                self?.finishMigration(serviceId: AppleCalendarService.id, version, database)
            }
        )
    }

    private func finishMigration(serviceId: String, _ version: Int32, _ database: any DataBase) {
        logger.log(.sql, level: .info, "external calendar db migration finished, service: \(serviceId), to: \(version)")
        try? database.updateJournalMode("WAL")
    }

    private func runGoogleCalendarEventTagMigration(_ version: Int32, _ database: any DataBase) throws {
        do {
            try database.migrate(GoogleCalendarEventTagTable.self, version: version)
            logger.log(.sql, level: .info, "google calendar db migration version \(version) -> \(version + 1), GoogleCalendarEventTagTable finished")
        } catch {
            logger.log(.sql, level: .error, "google calendar db migration version \(version) -> \(version + 1) failed, reason: \(error).. will drop GoogleCalendarEventTagTable")
            try? database.dropTable(GoogleCalendarEventTagTable.self)
        }
    }
}
