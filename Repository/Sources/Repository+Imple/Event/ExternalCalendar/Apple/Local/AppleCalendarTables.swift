//
//  AppleCalendarTables.swift
//  Repository
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService


// MARK: - AppleCalendarTagTable

struct AppleCalendarTagTable: Table {

    enum Columns: String, TableColumn {
        case id = "tag_id"
        case name
        case colorHex = "color_hex"

        var dataType: ColumnDataType {
            switch self {
            case .id: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .colorHex: return .text([])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = AppleCalendar.Tag
    static let tableName = "apple_calendar_tags"

    static func scalar(_ entity: AppleCalendar.Tag, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .id: return entity.id
        case .name: return entity.name
        case .colorHex: return entity.colorHex
        }
    }
}

extension AppleCalendar.Tag: @retroactive RowValueType {

    public init(_ cursor: CursorIterator) throws {
        self.init(
            id: try cursor.next().unwrap(),
            name: try cursor.next().unwrap(),
            colorHex: cursor.next()
        )
    }
}


// MARK: - AppleCalendarEventTable

struct AppleCalendarEventTable: Table {

    struct Entity: RowValueType {
        let eventId: String
        let originalEventId: String
        let calendarId: String
        let name: String
        let isRepeating: Bool
        let location: String?
        let url: String?
        let notes: String?

        init(_ event: AppleCalendar.Event) {
            self.eventId = event.eventId
            self.originalEventId = event.originalEventId
            self.calendarId = event.calendarId
            self.name = event.name
            self.isRepeating = event.isRepeating
            self.location = event.location
            self.url = nil
            self.notes = nil
        }

        init(_ cursor: CursorIterator) throws {
            self.eventId = try cursor.next().unwrap()
            self.originalEventId = try cursor.next().unwrap()
            self.calendarId = try cursor.next().unwrap()
            self.name = try cursor.next().unwrap()
            self.isRepeating = (try? cursor.next().unwrap()) ?? false
            self.location = cursor.next()
            self.url = cursor.next()
            self.notes = cursor.next()
        }
    }

    enum Columns: String, TableColumn {
        case eventId = "event_id"
        case originalEventId = "original_event_id"
        case calendarId = "calendar_id"
        case name
        case isRepeating = "is_repeating"
        case location
        case url
        case notes

        var dataType: ColumnDataType {
            switch self {
            case .eventId: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .originalEventId: return .text([.notNull])
            case .calendarId: return .text([.notNull])
            case .name: return .text([.notNull])
            case .isRepeating: return .integer([])
            case .location: return .text([])
            case .url: return .text([])
            case .notes: return .text([])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = Entity
    static let tableName = "apple_calendar_events"

    static func scalar(_ entity: Entity, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .eventId: return entity.eventId
        case .originalEventId: return entity.originalEventId
        case .calendarId: return entity.calendarId
        case .name: return entity.name
        case .isRepeating: return entity.isRepeating ? 1 : 0
        case .location: return entity.location
        case .url: return entity.url
        case .notes: return entity.notes
        }
    }

}
