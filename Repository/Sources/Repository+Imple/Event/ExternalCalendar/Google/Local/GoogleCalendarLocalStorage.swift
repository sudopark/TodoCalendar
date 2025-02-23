//
//  GoogleCalendarLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService


public protocol GoogleCalendarLocalStorage: Sendable {
 
    func loadColors() async throws -> GoogleCalendar.Colors?
    func updateColors(_ colors: GoogleCalendar.Colors) async throws
    func loadCalendarList() async throws -> [GoogleCalendar.Tag]
    func updateCalendarList(_ calendars: [GoogleCalendar.Tag]) async throws
}


public final class GoogleCalendarLocalStorageImple: GoogleCalendarLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Colors = GoogleCalendarColorsTable
    private typealias Calendars = GoogleCalendarEventTagTable
}


extension GoogleCalendarLocalStorageImple {
    
    public func loadColors() async throws -> GoogleCalendar.Colors? {
        let entities = try await self.sqliteService.async.run { db in
            let query = Colors.selectAll()
            return try db.load(Colors.self, query: query)
        }
        guard !entities.isEmpty else { return nil }
        
        let calendars = entities.filter { $0.colorType == "calendar" }
            .reduce(into: [String: GoogleCalendar.Colors.ColorSet]()) { acc, entity in
                acc[entity.colorKey] = GoogleCalendar.Colors.ColorSet(
                    foregroundHex: entity.foreground, backgroudHex: entity.background
                )
            }
        let events = entities.filter { $0.colorKey == "event" }
            .reduce(into: [String: GoogleCalendar.Colors.ColorSet]()) { acc, entity in
                acc[entity.colorKey] = GoogleCalendar.Colors.ColorSet(
                    foregroundHex: entity.foreground, backgroudHex: entity.background
                )
            }
        return .init(calendars: calendars, events: events)
    }
    
    public func updateColors(_ colors: GoogleCalendar.Colors) async throws {
        let calendars = colors.calendars.reduce([Colors.Entity]()) { arr, color in
            arr + [.init(calendar: color.key, color.value)]
        }
        let events = colors.events.reduce([Colors.Entity]()) { arr, color in
            arr + [.init(event: color.key, color.value)]
        }
        let entities = calendars + events
        try await self.sqliteService.async.run { db in
            try db.dropTable(Colors.self)
            try db.insert(Colors.self, entities: entities)
        }
    }
    
    public func loadCalendarList() async throws -> [GoogleCalendar.Tag] {
        return try await self.sqliteService.async.run { db in
            let query = Calendars.selectAll()
            return try db.load(query)
        }
    }
    
    public func updateCalendarList(_ calendars: [GoogleCalendar.Tag]) async throws {
        try await self.sqliteService.async.run { db in
            try db.dropTable(Calendars.self)
            try db.insert(Calendars.self, entities: calendars)
        }
    }
}
