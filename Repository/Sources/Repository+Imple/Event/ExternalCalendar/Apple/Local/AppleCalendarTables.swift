//
//  AppleCalendarTables.swift
//  Repository
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import SQLiteServiceMacros


// MARK: - AppleCalendarTagTable

typealias AppleCalendarTagTable = AppleCalendarTagTableV0

@Table("apple_calendar_tags")
struct AppleCalendarTagTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "tag_id")
    let id: String
    
    @Column(.notNull)
    let name: String
    
    @Column(name: "color_hex")
    var colorHex: String?
}


// MARK: - AppleCalendar.Tag 변환

extension AppleCalendarTagTable.Entity {

    init(_ tag: AppleCalendar.Tag) {
        self.init(
            id: tag.id,
            name: tag.name,
            colorHex: tag.colorHex
        )
    }

    func asTag() -> AppleCalendar.Tag {
        return AppleCalendar.Tag(
            id: self.id,
            name: self.name,
            colorHex: self.colorHex
        )
    }
}


// MARK: - AppleCalendarEventTable

typealias AppleCalendarEventTable = AppleCalendarEventTableV0

@Table("apple_calendar_events")
struct AppleCalendarEventTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "event_id")
    let eventId: String
    
    @Column(.notNull, name: "original_event_id")
    let originalEventId: String
    
    @Column(.notNull, name: "calendar_id")
    let calendarId: String
    
    @Column(.notNull)
    let name: String
    
    @Column(name: "is_repeating")
    var isRepeating: Bool?
    
    @Column()
    var location: String?
    
    @Column(name: "recurrence_rules")
    var recurrenceRules: String?
    
    @Column()
    var attendees: String?
    
    @Column()
    var url: String?
    
    @Column()
    var notes: String?
}


// MARK: - AppleCalendar.EventOrigin 변환

extension AppleCalendarEventTable.Entity {

    init(_ origin: AppleCalendar.EventOrigin) {
        self.init(
            eventId: origin.eventId,
            originalEventId: origin.originalEventId,
            calendarId: origin.calendarId,
            name: origin.name,
            isRepeating: origin.isRepeating,
            location: origin.location,
            recurrenceRules: origin.recurrenceRules.asRecurrenceRulesText(),
            attendees: origin.attendees.asAttendeesText(),
            url: origin.url,
            notes: origin.notes
        )
    }

    func asEventOrigin(eventTime: EventTime) -> AppleCalendar.EventOrigin {
        return AppleCalendar.EventOrigin(
            eventId: self.eventId,
            originalEventId: self.originalEventId,
            calendarId: self.calendarId,
            name: self.name,
            eventTime: eventTime
        )
        |> \.isRepeating .~ (self.isRepeating ?? false)
        |> \.location .~ self.location
        |> \.recurrenceRules .~ self.recurrenceRules.decodeRecurrenceRules()
        |> \.attendees .~ self.attendees.decodeAttendees()
        |> \.url .~ self.url
        |> \.notes .~ self.notes
    }
}

private extension Array where Element == String {

    func asRecurrenceRulesText() -> String? {
        guard !self.isEmpty,
              let data = try? JSONEncoder().encode(self)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private extension Array where Element == AppleCalendar.Attendee {

    func asAttendeesText() -> String? {
        guard !self.isEmpty else { return nil }
        let dicts = self.map { attendee -> [String: String] in
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

private extension Optional where Wrapped == String {

    func decodeRecurrenceRules() -> [String] {
        guard let json = self,
              let data = json.data(using: .utf8),
              let rules = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return rules
    }

    func decodeAttendees() -> [AppleCalendar.Attendee] {
        guard let json = self,
              let data = json.data(using: .utf8),
              let dicts = try? JSONDecoder().decode([[String: String]].self, from: data)
        else { return [] }
        return dicts.map { dict in
            return AppleCalendar.Attendee(name: dict["name"], email: dict["email"])
                |> \.isOrganizer .~ (dict["isOrganizer"] == "true")
                |> \.isCurrentUser .~ (dict["isCurrentUser"] == "true")
                |> \.status .~ (AppleCalendar.Attendee.Status(rawValue: dict["status"] ?? "") ?? .unknown)
        }
    }
}
