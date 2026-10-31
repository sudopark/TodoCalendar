//
//  GoogleCalendarTables.swift
//  ExternalCalendarDomain
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import ExternalCalendarDomainInterface


// MARK: - Colors 메인DB 스키마 (이관이 읽고 drop 한다)

@Table("google_calendar_colors")
public struct GoogleCalendarColorsTableV0 {

    @Column(.notNull, name: "color_type")
    public let colorType: String

    @Column(.notNull, name: "color_key")
    public let colorKey: String

    @Column(.notNull)
    public let background: String

    @Column(.notNull)
    public let foreground: String
}


// MARK: - Colors (google_calendar.db 신규 테이블, accountId 포함)

public typealias GoogleCalendarColorsTable = GoogleCalendarColorsTableV1

@Table("google_calendar_colors")
public struct GoogleCalendarColorsTableV1 {

    @Column(.notNull, name: "account_id")
    public let accountId: String

    @Column(.notNull, name: "color_type")
    public let colorType: String

    @Column(.notNull, name: "color_key")
    public let colorKey: String

    @Column(.notNull)
    public let background: String

    @Column(.notNull)
    public let foreground: String
}


// MARK: - Colors 변환

extension GoogleCalendarColorsTableV0.Entity {

    public init(calendar key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            colorType: "calendar",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }

    public init(event key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            colorType: "event",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }
}

extension GoogleCalendarColorsTable.Entity {

    public init(accountId: String, calendar key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            accountId: accountId,
            colorType: "calendar",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }

    public init(accountId: String, event key: String, _ colorSet: GoogleCalendar.Colors.ColorSet) {
        self.init(
            accountId: accountId,
            colorType: "event",
            colorKey: key,
            background: colorSet.backgroudHex,
            foreground: colorSet.foregroundHex
        )
    }
}



// MARK: - EventOrigin 메인DB 스키마 (이관이 읽고 drop 한다)

@Table("google_calendar_event_origin")
public struct GoogleCalendarEventOriginTableV0 {

    @Column(.notNull)
    public let calendarId: String

    @Column()
    public var defaultTimeZone: String?

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    public let id: String

    @Column(.notNull)
    public var summary: String?

    @Column()
    public var htmlLink: String?

    @Column()
    public var description: String?

    @Column()
    public var location: String?

    @Column()
    public var colorId: String?

    @Column()
    public var creator: String?

    @Column()
    public var organizer: String?

    @Column()
    public var start: String?

    @Column()
    public var end: String?

    @Column(.default(0))
    public var endTimeUnspecified: Bool?

    @Column()
    public var recurrence: String?

    @Column()
    public var recurringEventId: String?

    @Column()
    public var sequence: Int?

    @Column()
    public var attendees: String?

    @Column()
    public var hangoutLink: String?

    @Column()
    public var conferenceData: String?

    @Column()
    public var attachments: String?

    @Column()
    public var eventType: String?

    @Column()
    public var status: String?

    @Column()
    public var visibility: String?
}


extension GoogleCalendarEventOriginTableV0 {

    public static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 1:
            return Self.addColumnStatement(.status)
        case 3:
            return Self.addColumnStatement(.visibility)
        default: return nil
        }
    }
}


// MARK: - EventOrigin (google_calendar.db 신규 테이블, accountId 포함)

public typealias GoogleCalendarEventOriginTable = GoogleCalendarEventOriginTableV1

@Table("google_calendar_event_origin")
public struct GoogleCalendarEventOriginTableV1 {

    @Column(.notNull, name: "account_id")
    public let accountId: String

    @Column(.notNull)
    public let calendarId: String

    @Column()
    public var defaultTimeZone: String?

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    public let id: String

    @Column(.notNull)
    public var summary: String?

    @Column()
    public var htmlLink: String?

    @Column()
    public var description: String?

    @Column()
    public var location: String?

    @Column()
    public var colorId: String?

    @Column()
    public var creator: String?

    @Column()
    public var organizer: String?

    @Column()
    public var start: String?

    @Column()
    public var end: String?

    @Column(.default(0))
    public var endTimeUnspecified: Bool?

    @Column()
    public var recurrence: String?

    @Column()
    public var recurringEventId: String?

    @Column()
    public var sequence: Int?

    @Column()
    public var attendees: String?

    @Column()
    public var hangoutLink: String?

    @Column()
    public var conferenceData: String?

    @Column()
    public var attachments: String?

    @Column()
    public var eventType: String?

    @Column()
    public var status: String?

    @Column()
    public var visibility: String?
}


// MARK: - EventOrigin 변환

extension GoogleCalendarEventOriginTableV0.Entity {

    public init(
        _ calendarId: String,
        _ defaultTimeZone: String?,
        _ origin: GoogleCalendar.EventOrigin
    ) {
        self.init(
            calendarId: calendarId,
            defaultTimeZone: defaultTimeZone,
            id: origin.id,
            summary: origin.summary ?? "",
            htmlLink: origin.htmlLink,
            description: origin.description,
            location: origin.location,
            colorId: origin.colorId,
            creator: origin.creator?.asText(),
            organizer: origin.organizer?.asText(),
            start: origin.start?.asText(),
            end: origin.end?.asText(),
            endTimeUnspecified: origin.endTimeUnspecified,
            recurrence: origin.recurrence?.asText(),
            recurringEventId: origin.recurringEventId,
            sequence: origin.sequence,
            attendees: origin.attendees?.asText(),
            hangoutLink: origin.hangoutLink,
            conferenceData: origin.conferenceData?.asText(),
            attachments: origin.attachments?.asText(),
            eventType: origin.eventType,
            status: origin.status?.rawValue,
            visibility: origin.visibility?.rawValue
        )
    }

    public func asEventOrigin() -> GoogleCalendar.EventOrigin {
        var origin = GoogleCalendar.EventOrigin(id: self.id, summary: self.summary)
        origin.htmlLink = self.htmlLink
        origin.description = self.description
        origin.location = self.location
        origin.colorId = self.colorId
        origin.creator = self.creator.decodeJSON()
        origin.organizer = self.organizer.decodeJSON()
        origin.start = self.start.decodeJSON()
        origin.end = self.end.decodeJSON()
        origin.endTimeUnspecified = self.endTimeUnspecified
        origin.recurrence = self.recurrence.decodeJSON()
        origin.recurringEventId = self.recurringEventId
        origin.sequence = self.sequence
        origin.attendees = self.attendees.decodeJSON()
        origin.hangoutLink = self.hangoutLink
        origin.conferenceData = self.conferenceData.decodeJSON()
        origin.attachments = self.attachments.decodeJSON()
        origin.eventType = self.eventType
        origin.status = self.status.flatMap { .init(rawValue: $0) }
        origin.visibility = self.visibility.flatMap { .init(rawValue: $0) }
        return origin
    }
}

extension GoogleCalendarEventOriginTable.Entity {

    public init(
        accountId: String,
        _ calendarId: String,
        _ defaultTimeZone: String?,
        _ origin: GoogleCalendar.EventOrigin
    ) {
        self.init(
            accountId: accountId,
            calendarId: calendarId,
            defaultTimeZone: defaultTimeZone,
            id: origin.id,
            summary: origin.summary ?? "",
            htmlLink: origin.htmlLink,
            description: origin.description,
            location: origin.location,
            colorId: origin.colorId,
            creator: origin.creator?.asText(),
            organizer: origin.organizer?.asText(),
            start: origin.start?.asText(),
            end: origin.end?.asText(),
            endTimeUnspecified: origin.endTimeUnspecified,
            recurrence: origin.recurrence?.asText(),
            recurringEventId: origin.recurringEventId,
            sequence: origin.sequence,
            attendees: origin.attendees?.asText(),
            hangoutLink: origin.hangoutLink,
            conferenceData: origin.conferenceData?.asText(),
            attachments: origin.attachments?.asText(),
            eventType: origin.eventType,
            status: origin.status?.rawValue,
            visibility: origin.visibility?.rawValue
        )
    }

    public func asEventOrigin() -> GoogleCalendar.EventOrigin {
        var origin = GoogleCalendar.EventOrigin(id: self.id, summary: self.summary)
        origin.htmlLink = self.htmlLink
        origin.description = self.description
        origin.location = self.location
        origin.colorId = self.colorId
        origin.creator = self.creator.decodeJSON()
        origin.organizer = self.organizer.decodeJSON()
        origin.start = self.start.decodeJSON()
        origin.end = self.end.decodeJSON()
        origin.endTimeUnspecified = self.endTimeUnspecified
        origin.recurrence = self.recurrence.decodeJSON()
        origin.recurringEventId = self.recurringEventId
        origin.sequence = self.sequence
        origin.attendees = self.attendees.decodeJSON()
        origin.hangoutLink = self.hangoutLink
        origin.conferenceData = self.conferenceData.decodeJSON()
        origin.attachments = self.attachments.decodeJSON()
        origin.eventType = self.eventType
        origin.status = self.status.flatMap { .init(rawValue: $0) }
        origin.visibility = self.visibility.flatMap { .init(rawValue: $0) }
        return origin
    }
}


// MARK: - JSON 컬럼 직렬화

private extension Encodable {

    func asText() -> String? {
        let encoder = JSONEncoder()
        return (try? encoder.encode(self))
            .flatMap { String(data: $0, encoding: .utf8) }
    }
}

private extension Optional where Wrapped == String {

    func decodeJSON<D: Decodable>() -> D? {
        return self?.data(using: .utf8).flatMap {
            let decoder = JSONDecoder()
            return try? decoder.decode(D.self, from: $0)
        }
    }
}
