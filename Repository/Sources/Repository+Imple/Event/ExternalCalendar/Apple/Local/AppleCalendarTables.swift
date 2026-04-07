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
        let recurrenceRules: [String]
        let attendees: [AppleCalendar.Attendee]
        let url: String?
        let notes: String?

        init(_ origin: AppleCalendar.EventOrigin) {
            self.eventId = origin.eventId
            self.originalEventId = origin.originalEventId
            self.calendarId = origin.calendarId
            self.name = origin.name
            self.isRepeating = origin.isRepeating
            self.location = origin.location
            self.recurrenceRules = origin.recurrenceRules
            self.attendees = origin.attendees
            self.url = origin.url
            self.notes = origin.notes
        }

        init(_ cursor: CursorIterator) throws {
            self.eventId = try cursor.next().unwrap()
            self.originalEventId = try cursor.next().unwrap()
            self.calendarId = try cursor.next().unwrap()
            self.name = try cursor.next().unwrap()
            self.isRepeating = (try? cursor.next().unwrap()) ?? false
            self.location = cursor.next()
            self.recurrenceRules = Self.decodeRules(cursor.next())
            self.attendees = Self.decodeAttendees(cursor.next())
            self.url = cursor.next()
            self.notes = cursor.next()
        }

        func asEventOrigin(eventTime: EventTime) -> AppleCalendar.EventOrigin {
            var origin = AppleCalendar.EventOrigin(
                eventId: eventId,
                originalEventId: originalEventId,
                calendarId: calendarId,
                name: name,
                eventTime: eventTime
            )
            origin.isRepeating = isRepeating
            origin.location = location
            origin.recurrenceRules = recurrenceRules
            origin.attendees = attendees
            origin.url = url
            origin.notes = notes
            return origin
        }

        private static func decodeRules(_ json: String?) -> [String] {
            guard let json,
                  let data = json.data(using: .utf8),
                  let rules = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return rules
        }

        private static func decodeAttendees(_ json: String?) -> [AppleCalendar.Attendee] {
            guard let json,
                  let data = json.data(using: .utf8),
                  let dicts = try? JSONDecoder().decode([[String: String]].self, from: data)
            else { return [] }
            return dicts.map { dict in
                var attendee = AppleCalendar.Attendee(
                    name: dict["name"],
                    email: dict["email"]
                )
                attendee.isOrganizer = dict["isOrganizer"] == "true"
                attendee.isCurrentUser = dict["isCurrentUser"] == "true"
                attendee.status = AppleCalendar.Attendee.Status(rawValue: dict["status"] ?? "") ?? .unknown
                return attendee
            }
        }
    }

    enum Columns: String, TableColumn {
        case eventId = "event_id"
        case originalEventId = "original_event_id"
        case calendarId = "calendar_id"
        case name
        case isRepeating = "is_repeating"
        case location
        case recurrenceRules = "recurrence_rules"
        case attendees
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
            case .recurrenceRules: return .text([])
            case .attendees: return .text([])
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
        case .recurrenceRules: return encodeRules(entity.recurrenceRules)
        case .attendees: return encodeAttendees(entity.attendees)
        case .url: return entity.url
        case .notes: return entity.notes
        }
    }

    private static func encodeRules(_ rules: [String]) -> String? {
        guard !rules.isEmpty,
              let data = try? JSONEncoder().encode(rules)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func encodeAttendees(_ attendees: [AppleCalendar.Attendee]) -> String? {
        guard !attendees.isEmpty else { return nil }
        let dicts = attendees.map { attendee -> [String: String] in
            var dict: [String: String] = [:]
            if let name = attendee.name { dict["name"] = name }
            if let email = attendee.email { dict["email"] = email }
            dict["isOrganizer"] = attendee.isOrganizer ? "true" : "false"
            dict["isCurrentUser"] = attendee.isCurrentUser ? "true" : "false"
            dict["status"] = attendee.status.rawValue
            return dict
        }
        guard let data = try? JSONEncoder().encode(dicts) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
