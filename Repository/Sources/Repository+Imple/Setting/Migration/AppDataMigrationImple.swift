//
//  AppDataMigrationImple.swift
//  Repository
//
//  Created by sudo.park on 3/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService
import Extensions


public final class AppDataMigrationImple: @unchecked Sendable {

    private let mainDB: SQLiteService
    private let googleCalendarDBPool: any ExternalCalendarDBConnectionPool
    private let migrationFlagStorage: any EnvironmentStorage
    private let dbVersion: Int32

    public init(
        mainDB: SQLiteService,
        googleCalendarDBPool: any ExternalCalendarDBConnectionPool,
        migrationFlagStorage: any EnvironmentStorage,
        dbVersion: Int32
    ) {
        self.mainDB = mainDB
        self.googleCalendarDBPool = googleCalendarDBPool
        self.migrationFlagStorage = migrationFlagStorage
        self.dbVersion = dbVersion
    }

    public func runDBMigration() async throws {
        do {
            let _ = try await mainDB.async.migrate(
                upto: dbVersion,
                steps: { [weak self] version, database in
                    switch version {
                    case 0: try self?.runMigrationVersion0To1(database)
                    case 1: try self?.runMigrationVersion1to2(database)
                    case 2: try self?.runMigrationVersion2to3(database)
                    case 3: try self?.runMigrationVersion3to4(database)
                    case 4: try? self?.runMigrationVersion4to5(database)
                    case 5: try? self?.runMigrationVersion5to6(database)
                    default: break
                    }
                },
                finalized: { [weak self] version, database in
                    logger.log(.sql, level: .info, "db migration finished to: \(version)")
                    try? self?.updateJournalModeIfNeed(database)
                }
            )
        } catch {
            logger.log(.sql, level: .error, "db migration failed, reason: \(error)")
        }
    }

    public func prepareTables() async throws {
        try await mainDB.async.run { db in
            try? db.createTableOrNot(KeyValueTable.self)
            try? db.createTableOrNot(HolidayRepositoryImple.HolidayTable.self)
            try? db.createTableOrNot(EventTimeTable.self)
            try? db.createTableOrNot(EventDetailDataTable.self)
            try? db.createTableOrNot(CustomEventTagTable.self)
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


// MARK: - DB Migration steps

extension AppDataMigrationImple {

    private func runMigrationVersion0To1(_ database: any DataBase) throws {
        do {
            try database.migrate(TodoEventTable.self, version: 0)
            logger.log(.sql, level: .info, "migration version 0 -> 1, TodoEventTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 0 -> 1 failed.. will drop TodoEventTable")
            try? database.dropTable(TodoEventTable.self)
        }
        do {
            try database.migrate(ScheduleEventTable.self, version: 0)
            logger.log(.sql, level: .info, "migration version 0 -> 1, ScheduleEventTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 0 -> 1 failed.. will drop ScheduleEventTable")
            try? database.dropTable(ScheduleEventTable.self)
        }
        do {
            try database.migrate(PendingDoneTodoEventTable.self, version: 0)
            logger.log(.sql, level: .info, "migration version 0 -> 1, PendingDoneTodoEventTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 0 -> 1 failed.. will drop PendingDoneTodoEventTable")
            try? database.dropTable(PendingDoneTodoEventTable.self)
        }
    }

    private func runMigrationVersion1to2(_ database: any DataBase) throws {
        do {
            try database.migrate(OldGoogleCalendarEventOriginTable.self, version: 1)
            logger.log(.sql, level: .info, "migration version 1 -> 2, OldGoogleCalendarEventOriginTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 1 -> 2 failed.. will drop OldGoogleCalendarEventOriginTable")
            try? database.dropTable(OldGoogleCalendarEventOriginTable.self)
        }
    }

    private func runMigrationVersion2to3(_ database: any DataBase) throws {
        do {
            try database.migrate(OldGoogleCalendarEventTagTable.self, version: 2)
            logger.log(.sql, level: .info, "migration version 2 -> 3, OldGoogleCalendarEventTagTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 2 -> 3 failed.. will drop OldGoogleCalendarEventTagTable")
            try? database.dropTable(OldGoogleCalendarEventTagTable.self)
        }
    }

    private func runMigrationVersion3to4(_ database: any DataBase) throws {
        do {
            try database.migrate(OldGoogleCalendarEventOriginTable.self, version: 3)
            logger.log(.sql, level: .info, "migration version 3 -> 4, OldGoogleCalendarEventOriginTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 3 -> 4 failed.. will drop OldGoogleCalendarEventOriginTable")
            try? database.dropTable(OldGoogleCalendarEventOriginTable.self)
        }
    }

    private func runMigrationVersion4to5(_ database: any DataBase) throws {
        do {
            try database.createTableOrNot(EventUploadPendingQueueTableV4TempTable.self)
            try database.migrate(EventUploadPendingQueueTable.self, version: 4)
            logger.log(.sql, level: .info, "migration version 4 -> 5, EventUploadPendingQueueTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 4 -> 5 failed.. will drop EventUploadPendingQueueTable")
            try? database.dropTable(EventUploadPendingQueueTable.self)
        }
    }

    private func runMigrationVersion5to6(_ database: any DataBase) throws {
        do {
            try database.createTableOrNot(TodoEventTable.self)
            try database.migrate(TodoEventTable.self, version: 5)
            logger.log(.sql, level: .info, "migration version 5 -> 6, TodoEventTable finished")
        } catch {
            logger.log(.sql, level: .error, "migration version 5 -> 6 failed.. will drop TodoEventTable")
            try? database.dropTable(TodoEventTable.self)
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


// MARK: - Google Calendar data migration

extension AppDataMigrationImple {

    private var googleCalendarMigrationFlagKey: String {
        "google_calendar_migrated"
    }

    public func migrateGoogleCalendarDataIfNeeded(accountId: String) async {
        let key = googleCalendarMigrationFlagKey
        guard migrationFlagStorage.load(key) != true else { return }

        if let (colors, tags, origins) = try? await readFromMainDB() {
            let eventIds = origins.map { $0.origin.id }
            let times = (try? await readEventTimes(eventIds: eventIds)) ?? []
            try? await writeToGoogleCalendarDB(
                accountId: accountId,
                colors: colors,
                tags: tags,
                origins: origins,
                times: times
            )
            try? await cleanupMainDB(eventIds: eventIds)
        }

        migrationFlagStorage.update(key, true)
    }

    private func readFromMainDB() async throws -> (
        [OldGoogleCalendarColorsTable.Entity],
        [GoogleCalendar.Tag],
        [OldGoogleCalendarEventOriginTable.Entity]
    ) {
        let colors = try await mainDB.async.run { db -> [OldGoogleCalendarColorsTable.Entity] in
            try? db.createTableOrNot(OldGoogleCalendarColorsTable.self)
            let query = OldGoogleCalendarColorsTable.selectAll()
            return (try? db.load(OldGoogleCalendarColorsTable.self, query: query)) ?? []
        }

        let tags = try await mainDB.async.run { db -> [GoogleCalendar.Tag] in
            try? db.createTableOrNot(OldGoogleCalendarEventTagTable.self)
            let query = OldGoogleCalendarEventTagTable.selectAll()
            return (try? db.load(query)) ?? []
        }

        let origins = try await mainDB.async.run { db -> [OldGoogleCalendarEventOriginTable.Entity] in
            try? db.createTableOrNot(OldGoogleCalendarEventOriginTable.self)
            let query = OldGoogleCalendarEventOriginTable.selectAll()
            return (try? db.load(OldGoogleCalendarEventOriginTable.self, query: query)) ?? []
        }

        return (colors, tags, origins)
    }

    private func readEventTimes(eventIds: [String]) async throws -> [EventTimeTable.Entity] {
        guard !eventIds.isEmpty else { return [] }
        return try await mainDB.async.run { db in
            let query = EventTimeTable.selectAll { $0.eventId.in(eventIds) }
            return (try? db.load(EventTimeTable.self, query: query)) ?? []
        }
    }

    private func writeToGoogleCalendarDB(
        accountId: String,
        colors: [OldGoogleCalendarColorsTable.Entity],
        tags: [GoogleCalendar.Tag],
        origins: [OldGoogleCalendarEventOriginTable.Entity],
        times: [EventTimeTable.Entity]
    ) async throws {
        let googleDB = try await googleCalendarDBPool.connection(serviceId: GoogleCalendarService.id)

        try await googleDB.async.run { db in
            try db.createTableOrNot(GoogleCalendarColorsTable.self)
            let colorEntities = colors.map {
                GoogleCalendarColorsTable.Entity(accountId: accountId, migrating: $0)
            }
            if !colorEntities.isEmpty {
                try db.insert(GoogleCalendarColorsTable.self, entities: colorEntities)
            }

            try db.createTableOrNot(GoogleCalendarEventTagTable.self)
            let tagEntities = tags.map { GoogleCalendarEventTagTable.Entity(accountId: accountId, $0) }
            if !tagEntities.isEmpty {
                try db.insert(GoogleCalendarEventTagTable.self, entities: tagEntities)
            }

            try db.createTableOrNot(GoogleCalendarEventOriginTable.self)
            let originEntities = origins.map {
                GoogleCalendarEventOriginTable.Entity(accountId: accountId, $0.calendarId, $0.defaultTimeZone, $0.origin)
            }
            if !originEntities.isEmpty {
                try db.insert(GoogleCalendarEventOriginTable.self, entities: originEntities)
            }

            try db.createTableOrNot(EventTimeTable.self)
            if !times.isEmpty {
                try db.insert(EventTimeTable.self, entities: times)
            }
        }
    }

    private func cleanupMainDB(eventIds: [String]) async throws {
        try await mainDB.async.run { db in
            try? db.dropTable(OldGoogleCalendarColorsTable.self)
            try? db.dropTable(OldGoogleCalendarEventTagTable.self)
            try? db.dropTable(OldGoogleCalendarEventOriginTable.self)
            if !eventIds.isEmpty {
                let deleteQuery = EventTimeTable.delete().where { $0.eventId.in(eventIds) }
                try? db.delete(EventTimeTable.self, query: deleteQuery)
            }
        }
    }
}


// MARK: - Migration entity convenience

private extension GoogleCalendarColorsTable.Entity {

    init(accountId: String, migrating old: OldGoogleCalendarColorsTable.Entity) {
        self.accountId = accountId
        self.colorType = old.colorType
        self.colorKey = old.colorKey
        self.background = old.background
        self.foreground = old.foreground
    }
}
