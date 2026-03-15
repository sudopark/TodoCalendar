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
        try await mainDB.runMigration(upTo: dbVersion)
    }

    public func prepareTables() async throws {
        try await mainDB.prepareTables()
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
