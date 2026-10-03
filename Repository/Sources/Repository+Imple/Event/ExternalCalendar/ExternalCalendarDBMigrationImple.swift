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
        let _ = try await dbService.async.migrate(
            upto: self.googleCalendarDBVersion,
            steps: { [weak self] version, database in
                switch version {
                case 0: try self?.runGoogleCalendarEventTagMigration(version, database)
                default: break
                }
            },
            finalized: { version, database in
                logger.log(.sql, level: .info, "external calendar db migration finished to: \(version)")
                try? database.updateJournalMode("WAL")
            }
        )
    }
}


// MARK: - DB Migration steps

extension ExternalCalendarDBMigrationImple {

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
