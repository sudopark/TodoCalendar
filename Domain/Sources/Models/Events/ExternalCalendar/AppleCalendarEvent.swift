//
//  AppleCalendarEvent.swift
//  Domain
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - AppleCalendar namespace

public struct AppleCalendar { }


// MARK: - Tag

extension AppleCalendar {

    public struct Tag: EventTag {

        public let tagId: EventTagId
        public let id: String
        public let name: String
        public let colorHex: String?

        public init(id: String, name: String, colorHex: String?) {
            self.id = id
            self.tagId = .externalCalendar(serviceId: AppleCalendarService.id, id: id)
            self.name = name
            self.colorHex = colorHex
        }
    }
}


// MARK: - Event

extension AppleCalendar {

    public struct Event: Sendable {

        public let eventId: String
        public let originalEventId: String
        public let calendarId: String
        public var name: String
        public let eventTagId: EventTagId
        public let eventTime: EventTime
        public var isRepeating: Bool = false
        public var location: String?

        public init(
            eventId: String,
            originalEventId: String,
            calendarId: String,
            name: String,
            eventTime: EventTime
        ) {
            self.eventId = eventId
            self.originalEventId = originalEventId
            self.calendarId = calendarId
            self.name = name
            self.eventTagId = .externalCalendar(serviceId: AppleCalendarService.id, id: calendarId)
            self.eventTime = eventTime
        }
    }
}


// MARK: - Attendee

extension AppleCalendar {

    public struct Attendee: Sendable, Equatable {

        public enum Status: String, Sendable, Equatable {
            case unknown, pending, accepted, declined, tentative
        }

        public var name: String?
        public var email: String?
        public var isOrganizer: Bool = false
        public var isCurrentUser: Bool = false
        public var status: Status = .unknown

        public init(name: String? = nil, email: String? = nil) {
            self.name = name
            self.email = email
        }
    }
}


// MARK: - EventOrigin

extension AppleCalendar {

    public struct EventOrigin: Sendable {

        public let eventId: String
        public let originalEventId: String
        public let calendarId: String
        public var name: String
        public let eventTagId: EventTagId
        public let eventTime: EventTime
        public var isRepeating: Bool = false
        public var location: String?
        public var recurrenceRules: [String] = []
        public var attendees: [Attendee] = []
        public var url: String?
        public var notes: String?

        public init(
            eventId: String,
            originalEventId: String,
            calendarId: String,
            name: String,
            eventTime: EventTime
        ) {
            self.eventId = eventId
            self.originalEventId = originalEventId
            self.calendarId = calendarId
            self.name = name
            self.eventTagId = .externalCalendar(serviceId: AppleCalendarService.id, id: calendarId)
            self.eventTime = eventTime
        }

        public func asEvent() -> Event {
            var event = Event(
                eventId: eventId,
                originalEventId: originalEventId,
                calendarId: calendarId,
                name: name,
                eventTime: eventTime
            )
            event.isRepeating = isRepeating
            event.location = location
            return event
        }
    }
}
