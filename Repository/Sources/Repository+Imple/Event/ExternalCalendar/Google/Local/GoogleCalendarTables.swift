//
//  GoogleCalendarTables.swift
//  Repository
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import Domain
import SQLiteService
import Extensions


// MARK: - Colors 메인DB 스키마 (이관이 읽고 drop 한다)

@Table("google_calendar_colors")
struct GoogleCalendarColorsTableV0 {

    @Column(.notNull, name: "color_type")
    let colorType: String

    @Column(.notNull, name: "color_key")
    let colorKey: String

    @Column(.notNull)
    let background: String

    @Column(.notNull)
    let foreground: String
}


// MARK: - Colors (google_calendar.db 신규 테이블, accountId 포함)

typealias GoogleCalendarColorsTable = GoogleCalendarColorsTableV1

@Table("google_calendar_colors")
struct GoogleCalendarColorsTableV1 {

    @Column(.notNull, name: "account_id")
    let accountId: String

    @Column(.notNull, name: "color_type")
    let colorType: String

    @Column(.notNull, name: "color_key")
    let colorKey: String

    @Column(.notNull)
    let background: String

    @Column(.notNull)
    let foreground: String
}


// MARK: - Colors 변환

extension GoogleCalendarColorsTableV0.Entity {

    init(calendar key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            colorType: "calendar",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }

    init(event key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            colorType: "event",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }
}

extension GoogleCalendarColorsTable.Entity {

    init(accountId: String, calendar key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            accountId: accountId,
            colorType: "calendar",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }

    init(accountId: String, event key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            accountId: accountId,
            colorType: "event",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }
}


// MARK: - Old event (공통DB 레거시 테이블)

struct OldGoogleCalendarEventOriginTable: Table {
    
    enum Columns: String, TableColumn {
        case calendarId
        case defaultTimeZone
        case id
        case summary
        case htmlLink
        case description
        case location
        case colorId
        case creator
        case organizer
        case start
        case end
        case endTimeUnspecified
        case recurrence
        case recurringEventId
        case sequence
        case attendees
        case hangoutLink
        case conferenceData
        case attachments
        case eventType
        case status
        case visibility
        
        var dataType: ColumnDataType {
            switch self {
            case .calendarId: return .text([.notNull])
            case .defaultTimeZone: return .text([])
            case .id: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .summary: return .text([.notNull])
            case .htmlLink: return .text([])
            case .description: return .text([])
            case .location: return .text([])
            case .colorId: return .text([])
            case .creator: return .text([])
            case .organizer: return .text([])
            case .start: return .text([])
            case .end: return .text([])
            case .endTimeUnspecified: return .integer([.default(0)])
            case .recurrence: return .text([])
            case .recurringEventId: return .text([])
            case .sequence: return .integer([])
            case .attendees: return .text([])
            case .hangoutLink: return .text([])
            case .conferenceData: return .text([])
            case .attachments: return .text([])
            case .eventType: return .text([])
            case .status: return .text([])
            case .visibility: return .text([])
            }
        }
    }
    struct Entity: RowValueType {
        let calendarId: String
        let defaultTimeZone: String?
        let origin: GoogleCalendar.EventOrigin
        init(
            _ calendarId: String,
            _ defaultTimeZone: String?,
            _ origin: GoogleCalendar.EventOrigin
        ) {
            self.calendarId = calendarId
            self.defaultTimeZone = defaultTimeZone
            self.origin = origin
        }
        
        init(_ cursor: CursorIterator) throws {
            self.calendarId = try cursor.next().unwrap()
            self.defaultTimeZone = cursor.next()
            self.origin = try GoogleCalendar.EventOrigin(cursor)
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = Entity
    static let tableName: String = "google_calendar_event_origin"
    
    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 1:
            return Self.addColumnStatement(.status)
        case 3:
            return Self.addColumnStatement(.visibility)
        default: return nil
        }
    }
    
    static func scalar(
        _ entity: Entity, for column: Columns
    ) -> (any ScalarType)? {
        
        switch column {
        case .calendarId: return entity.calendarId
        case .defaultTimeZone: return entity.defaultTimeZone
        case .id: return entity.origin.id
        case .summary: return entity.origin.summary ?? ""
        case .htmlLink: return entity.origin.htmlLink
        case .description: return entity.origin.description
        case .location: return entity.origin.location
        case .colorId: return entity.origin.colorId
        case .creator: return entity.origin.creator?.asText()
        case .organizer: return entity.origin.organizer?.asText()
        case .start: return entity.origin.start?.asText()
        case .end: return entity.origin.end?.asText()
        case .endTimeUnspecified: return entity.origin.endTimeUnspecified
        case .recurrence: return entity.origin.recurrence?.asText()
        case .recurringEventId: return entity.origin.recurringEventId
        case .sequence: return entity.origin.sequence
        case .attendees: return entity.origin.attendees?.asText()
        case .hangoutLink: return entity.origin.hangoutLink
        case .conferenceData: return entity.origin.conferenceData?.asText()
        case .attachments: return entity.origin.attachments?.asText()
        case .eventType: return entity.origin.eventType
        case .status: return entity.origin.status?.rawValue
        case .visibility: return entity.origin.visibility?.rawValue
        }
    }
    
}

// MARK: - event (google_calendar.db 신규 테이블, accountId 포함)

struct GoogleCalendarEventOriginTable: Table {

    enum Columns: String, TableColumn {
        case accountId = "account_id"
        case calendarId
        case defaultTimeZone
        case id
        case summary
        case htmlLink
        case description
        case location
        case colorId
        case creator
        case organizer
        case start
        case end
        case endTimeUnspecified
        case recurrence
        case recurringEventId
        case sequence
        case attendees
        case hangoutLink
        case conferenceData
        case attachments
        case eventType
        case status
        case visibility

        var dataType: ColumnDataType {
            switch self {
            case .accountId: return .text([.notNull])
            case .calendarId: return .text([.notNull])
            case .defaultTimeZone: return .text([])
            case .id: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .summary: return .text([.notNull])
            case .htmlLink: return .text([])
            case .description: return .text([])
            case .location: return .text([])
            case .colorId: return .text([])
            case .creator: return .text([])
            case .organizer: return .text([])
            case .start: return .text([])
            case .end: return .text([])
            case .endTimeUnspecified: return .integer([.default(0)])
            case .recurrence: return .text([])
            case .recurringEventId: return .text([])
            case .sequence: return .integer([])
            case .attendees: return .text([])
            case .hangoutLink: return .text([])
            case .conferenceData: return .text([])
            case .attachments: return .text([])
            case .eventType: return .text([])
            case .status: return .text([])
            case .visibility: return .text([])
            }
        }
    }

    struct Entity: RowValueType {
        let accountId: String
        let calendarId: String
        let defaultTimeZone: String?
        let origin: GoogleCalendar.EventOrigin

        init(
            accountId: String,
            _ calendarId: String,
            _ defaultTimeZone: String?,
            _ origin: GoogleCalendar.EventOrigin
        ) {
            self.accountId = accountId
            self.calendarId = calendarId
            self.defaultTimeZone = defaultTimeZone
            self.origin = origin
        }

        init(_ cursor: CursorIterator) throws {
            self.accountId = try cursor.next().unwrap()
            self.calendarId = try cursor.next().unwrap()
            self.defaultTimeZone = cursor.next()
            self.origin = try GoogleCalendar.EventOrigin(cursor)
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = Entity
    static let tableName: String = "google_calendar_event_origin"

    static func scalar(
        _ entity: Entity, for column: Columns
    ) -> (any ScalarType)? {
        switch column {
        case .accountId: return entity.accountId
        case .calendarId: return entity.calendarId
        case .defaultTimeZone: return entity.defaultTimeZone
        case .id: return entity.origin.id
        case .summary: return entity.origin.summary ?? ""
        case .htmlLink: return entity.origin.htmlLink
        case .description: return entity.origin.description
        case .location: return entity.origin.location
        case .colorId: return entity.origin.colorId
        case .creator: return entity.origin.creator?.asText()
        case .organizer: return entity.origin.organizer?.asText()
        case .start: return entity.origin.start?.asText()
        case .end: return entity.origin.end?.asText()
        case .endTimeUnspecified: return entity.origin.endTimeUnspecified
        case .recurrence: return entity.origin.recurrence?.asText()
        case .recurringEventId: return entity.origin.recurringEventId
        case .sequence: return entity.origin.sequence
        case .attendees: return entity.origin.attendees?.asText()
        case .hangoutLink: return entity.origin.hangoutLink
        case .conferenceData: return entity.origin.conferenceData?.asText()
        case .attachments: return entity.origin.attachments?.asText()
        case .eventType: return entity.origin.eventType
        case .status: return entity.origin.status?.rawValue
        case .visibility: return entity.origin.visibility?.rawValue
        }
    }
}


extension GoogleCalendar.EventOrigin {
 
    public init(_ cursor: CursorIterator) throws {
        self.init(
            id: try cursor.next().unwrap(),
            summary: cursor.next()
        )
        self.htmlLink = cursor.next()
        self.description = cursor.next()
        self.location = cursor.next()
        self.colorId = cursor.next()
        self.creator = cursor.nextDecodable()
        self.organizer = cursor.nextDecodable()
        self.start = cursor.nextDecodable()
        self.end = cursor.nextDecodable()
        self.endTimeUnspecified = cursor.next()
        self.recurrence = cursor.nextDecodable()
        self.recurringEventId = cursor.next()
        self.sequence = cursor.next()
        self.attendees = cursor.nextDecodable()
        self.hangoutLink = cursor.next()
        self.conferenceData = cursor.nextDecodable()
        self.attachments = cursor.nextDecodable()
        self.eventType = cursor.next()
        let statusText: String? = cursor.next()
        self.status = statusText.flatMap { .init(rawValue: $0) }
        let visibilityText: String? = cursor.next()
        self.visibility = visibilityText.flatMap { .init(rawValue: $0) }
    }
}

private extension Encodable {
    
    func asText() -> String? {
        let encoder = JSONEncoder()
        return (try? encoder.encode(self))
            .flatMap { String(data: $0, encoding: .utf8) }
    }
}

private extension CursorIterator {
    
    func nextDecodable<D: Decodable>() -> D? {
        let text: String? = self.next()
        return text?.data(using: .utf8).flatMap {
            let decoder = JSONDecoder()
            return try? decoder.decode(D.self, from: $0)
        }
    }
}
