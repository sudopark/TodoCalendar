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
        public let calendarId: String
        public let name: String
        public let eventTagId: EventTagId
        public let eventTime: EventTime
        public let location: String?

        public init(
            eventId: String,
            calendarId: String,
            name: String,
            eventTime: EventTime,
            location: String? = nil
        ) {
            self.eventId = eventId
            self.calendarId = calendarId
            self.name = name
            self.eventTagId = .externalCalendar(serviceId: AppleCalendarService.id, id: calendarId)
            self.eventTime = eventTime
            self.location = location
        }
    }
}
