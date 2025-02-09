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
 
    func loadColors() async throws -> GoogleCalendarColors?
    func updateColors(_ colors: GoogleCalendarColors) async throws
}


public final class GoogleCalendarLocalStorageImple: GoogleCalendarLocalStorage {
    
    private let sqliteService: SQLiteService
    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
    
    private typealias Colors = GoogleCalendarColorsTable
}


extension GoogleCalendarLocalStorageImple {
    
    public func loadColors() async throws -> GoogleCalendarColors? {
        let entities = try await self.sqliteService.async.run { db in
            let query = Colors.selectAll()
            return try db.load(Colors.self, query: query)
        }
        guard !entities.isEmpty else { return nil }
        
        let calendars = entities.filter { $0.colorType == "calendar" }
            .reduce(into: [String: GoogleCalendarColors.ColorSet]()) { acc, entity in
                acc[entity.colorKey] = GoogleCalendarColors.ColorSet(
                    foregroundHex: entity.foreground, backgroudHex: entity.background
                )
            }
        let events = entities.filter { $0.colorKey == "event" }
            .reduce(into: [String: GoogleCalendarColors.ColorSet]()) { acc, entity in
                acc[entity.colorKey] = GoogleCalendarColors.ColorSet(
                    foregroundHex: entity.foreground, backgroudHex: entity.background
                )
            }
        return .init(calendars: calendars, events: events)
    }
    
    public func updateColors(_ colors: GoogleCalendarColors) async throws {
        try await self.sqliteService.async.run { try $0.dropTable(Colors.self) }
        let calendars = colors.calendars.reduce([Colors.Entity]()) { arr, color in
            arr + [.init(calendar: color.key, color.value)]
        }
        let events = colors.events.reduce([Colors.Entity]()) { arr, color in
            arr + [.init(event: color.key, color.value)]
        }
        let entities = calendars + events
        try await self.sqliteService.async.run { db in
            try db.insert(Colors.self, entities: entities)
        }
    }
}
