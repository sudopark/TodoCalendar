//
//  GoogleCalendarEvent.swift
//  DomainTests
//
//  Created by sudo.park on 2/23/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation

// MARK: - google calendar namespace

public struct GoogleCalendar { }


// MARK: - GoogleCalendar Color

extension GoogleCalendar {
    
    public struct Colors: Equatable, Sendable {
        
        public struct ColorSet: Equatable, Sendable {
            public let foregroundHex: String
            public let backgroudHex: String
            
            public init(foregroundHex: String, backgroudHex: String) {
                self.foregroundHex = foregroundHex
                self.backgroudHex = backgroudHex
            }
        }
        
        public let calendars: [String: ColorSet]
        public let events: [String: ColorSet]
        
        public init(calendars: [String : ColorSet], events: [String : ColorSet]) {
            self.calendars = calendars
            self.events = events
        }
    }
}


// MARK: - Event Tag

extension GoogleCalendar {
    
    public struct Tag: EventTag {
        
        public let tagId: EventTagId
        public let id: String
        public let name: String
        public var description: String?
        public var backgroundColorHex: String?
        public var foregroundColorHex: String?
        public var colorId: String?
        public var colorHex: String {
            return backgroundColorHex ?? "#000000"
        }
        
        public init(id: String, name: String) {
            self.id = id
            self.tagId = .externalCalendar(serviceId: GoogleCalendarService.id, id: id)
            self.name = name
        }
    }
}


// MARK: - event

extension GoogleCalendar {
    
    public struct Event: Codable, Sendable {
        public let id: String
        public let summary: String
        public var htmlLink: String?
        public var created: String?
        public var updated: String?
        public var description: String?
        public var location: String?
        public var colorId: String?
        public var creator: Creator?
        public var organizer: Organizer?
        public var start: EventTime?
        public var end: EventTime?
        public var endTimeUnspecified: Bool = false
        public var recurrence: [String]?
        public var recurringEventId: String?
        public var originalStartTime: EventTime?
        public var iCalUID: String?
        public var sequence: Int?
        public var attendees: [Attendee]?
        public var attendeesOmitted: Bool?
        public var hangoutLink: String?
        public var conferenceData: ConferenceData?
        public var attachments: [Attachment]?
        public var birthdayProperties: BirthdayProperties?
        public var eventType: String?
        
        public init(id: String, summary: String) {
            self.id = id
            self.summary = summary
        }

        public struct Creator: Codable, Sendable {
            public var id: String?
            public var email: String?
            public var displayName: String?
            public var selfValue: Bool?
            
            public init() { }
        }

        public struct Organizer: Codable, Sendable {
            public var id: String?
            public var email: String?
            public var displayName: String?
            public var selfValue: Bool?
            
            public init() { }
        }

        public struct EventTime: Codable, Sendable {
            public var date: String?
            public var dateTime: String?
            public var timeZone: String?
            
            public init() { }
        }

        public struct Attendee: Codable, Sendable {
            public var id: String?
            public var email: String?
            public var displayName: String?
            public var organizer: Bool?
            public var selfValue: Bool?
            public var resource: Bool?
            public var optional: Bool?
            public var responseStatus: String?
            public var comment: String?
            public var additionalGuests: Int?
            
            public init() { }
        }


        public struct ConferenceData: Codable, Sendable {
            public var createRequest: CreateRequest?
            public var entryPoints: [EntryPoint]?
            public var conferenceId: String?
            public var signature: String?
            public var notes: String?
            
            public init() { }

            public struct CreateRequest: Codable, Sendable {
                public var requestId: String?
                public var conferenceSolutionKey: String?
                public var status: String?
                
                public init() { }
            }

            public struct EntryPoint: Codable, Sendable {
                public var entryPointType: String?
                public var uri: String?
                public var label: String?
                public var pin: String?
                public var accessCode: String?
                public var meetingCode: String?
                public var passcode: String?
                public var password: String?
                
                public init() { }
            }
        }
        
        public struct Source: Codable, Sendable {
            public var url: String?
            public var title: String?
            
            public init() { }
        }
        
        public struct Attachment: Codable, Sendable {
            public var fileUrl: String?
            public var title: String?
            public var mimeType: String?
            public var iconLink: String?
            public var fileId: String?
            
            public init() { }
        }

        public struct BirthdayProperties: Codable, Sendable {
            public var contact: String?
            public var type: String?
            public var customTypeName: String?
            
            public init() { }
        }
    }
}
