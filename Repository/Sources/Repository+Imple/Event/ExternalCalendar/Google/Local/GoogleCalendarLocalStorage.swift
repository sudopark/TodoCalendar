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
    
    func loadEvents(_ calendarId: String, _ range: Range<TimeInterval>) async throws -> [GoogleCalendar.Event]
    func removeEvents(_ ids: [String]) async throws
    func updateEvents(
        _ calendarId: String,
        _ eventList: GoogleCalendar.EventOriginValueList,
        _ events: [GoogleCalendar.Event]
    ) async throws
    func loadEventDetail(_ eventId: String) async throws -> GoogleCalendar.EventOrigin
    func updateEventDetail(
        _ calendarId: String,
        _ defaultTimeZone: String?,
        _ origin: GoogleCalendar.EventOrigin
    ) async throws
    func resetAll() async throws
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

// MARK: - events

extension GoogleCalendarLocalStorageImple {
    
    private typealias Events = GoogleCalendarEventOriginTable
    private typealias Times = EventTimeTable
    
    public func loadEvents(
        _ calendarId: String, _ range: Range<TimeInterval>
    ) async throws -> [GoogleCalendar.Event] {
        let timeQuery = Times.overlapQuery(with: range)
        let eventQuery = Events
            .selectSome { [$0.id, $0.summary, $0.colorId, $0.htmlLink] }
            .where { $0.calendarId == calendarId }
        let query = eventQuery.innerJoin(with: timeQuery, on: { ($0.id, $1.eventId) })
        let mapping: (CursorIterator) throws -> GoogleCalendar.Event = { cursor in
            return .init(
                try cursor.next().unwrap(),
                calendarId,
                name: try cursor.next().unwrap(),
                colorId: cursor.next(),
                htmlLink: cursor.next(),
                time: try Times.Entity(cursor).eventTime.unwrap()
            )
        }
        return try await self.sqliteService.async.run { db in
            try db.createTableOrNot(Events.self)
            return try db.load(query, mapping: mapping)
        }
    }
    
    public func removeEvents(
        _ ids: [String]
    ) async throws {
        try await self.sqliteService.async.run { db in
            let query = Events.delete().where { $0.id.in(ids) }
            try db.delete(Events.self, query: query)
        }
        try await self.sqliteService.async.run { db in
            let query = Times.delete().where { $0.eventId.in(ids) }
            try db.delete(Times.self, query: query)
        }
    }
    
    public func updateEvents(
        _ calendarId: String,
        _ eventList: GoogleCalendar.EventOriginValueList,
        _ events: [GoogleCalendar.Event]
    ) async throws {
        try await self.sqliteService.async.run { db in
            let entities = eventList.items.map {
                Events.Entity(calendarId, eventList.timeZone, $0)
            }
            try db.insert(Events.self, entities: entities)
            
            let times = events.map {
                Times.Entity($0.eventId, $0.eventTime, nil)
            }
            try db.insert(Times.self, entities: times)
        }
    }
    
    public func loadEventDetail(
        _ eventId: String
    ) async throws -> GoogleCalendar.EventOrigin {
        let query = Events.selectAll { $0.id == eventId }
        let entity = try await self.sqliteService.async.run { db in
            return try db.loadOne(Events.self, query: query)
        }
        return try entity.unwrap().origin
    }
    
    public func updateEventDetail(
        _ calendarId: String,
        _ defaultTimeZone: String?,
        _ origin: GoogleCalendar.EventOrigin
    ) async throws {
        try await self.sqliteService.async.run { db in
            let entity = Events.Entity(calendarId, defaultTimeZone, origin)
            try db.insert(Events.self, entities: [entity])
            
            if let event = GoogleCalendar.Event(origin, calendarId, defaultTimeZone) {
             
                let timeEntity = Times.Entity(event.eventId, event.eventTime, nil)
                try db.insert(Times.self, entities: [timeEntity])
            }
        }
    }
    
    public func resetAll() async throws {

        try await self.sqliteService.async.run { db in
            try db.dropTable(Colors.self)
            try db.dropTable(Calendars.self)
            try db.dropTable(Events.self)
        }
    }
}
