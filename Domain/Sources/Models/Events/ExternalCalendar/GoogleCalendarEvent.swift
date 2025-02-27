//
//  GoogleCalendarEvent.swift
//  DomainTests
//
//  Created by sudo.park on 2/23/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Extensions

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
    
    public struct EventRawValue: Decodable, Sendable {
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
        public var start: GoogleEventTime?
        public var end: GoogleEventTime?
        public var endTimeUnspecified: Bool = false
        public var recurrence: [String]?
        public var recurringEventId: String?
        public var originalStartTime: GoogleEventTime?
        public var iCalUID: String?
        public var sequence: Int?
        public var attendees: [Attendee]?
        public var attendeesOmitted: Bool?
        public var hangoutLink: String?
        public var conferenceData: ConferenceData?
        public var attachments: [Attachment]?
        public var birthdayProperties: BirthdayProperties?
        public var eventType: String?
        
        public init(
            id: String, summary: String
        ) {
            self.id = id
            self.summary = summary
        }

        public struct Creator: Decodable, Sendable {
            public var id: String?
            public var email: String?
            public var displayName: String?
            public var selfValue: Bool?
            
            public init() { }
        }

        public struct Organizer: Decodable, Sendable {
            public var id: String?
            public var email: String?
            public var displayName: String?
            public var selfValue: Bool?
            
            public init() { }
        }

        public struct GoogleEventTime: Decodable, Sendable {
            public var date: String?
            public var dateTime: String?
            public var timeZone: String?
            
            public init() { }
        }

        public struct Attendee: Decodable, Sendable {
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


        public struct ConferenceData: Decodable, Sendable {
            public var createRequest: CreateRequest?
            public var entryPoints: [EntryPoint]?
            public var conferenceId: String?
            public var signature: String?
            public var notes: String?
            
            public init() { }

            public struct CreateRequest: Decodable, Sendable {
                public var requestId: String?
                public var conferenceSolutionKey: String?
                public var status: String?
                
                public init() { }
            }

            public struct EntryPoint: Decodable, Sendable {
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
        
        public struct Source: Decodable, Sendable {
            public var url: String?
            public var title: String?
            
            public init() { }
        }
        
        public struct Attachment: Decodable, Sendable {
            public var fileUrl: String?
            public var title: String?
            public var mimeType: String?
            public var iconLink: String?
            public var fileId: String?
            
            public init() { }
        }

        public struct BirthdayProperties: Decodable, Sendable {
            public var contact: String?
            public var type: String?
            public var customTypeName: String?
            
            public init() { }
        }
    }
    
    public struct Event: Sendable {
        public let origin: EventRawValue
        public let eventTime: EventTime
        public var repeating: EventRepeating?
        
        public var nextRepeatingTimes: [RepeatingTimes] = []
        public var repeatingTimeToExcludes: Set<String> = []
        
        public init?(_ origin: EventRawValue) {
            self.origin = origin
            let start = origin.start?.supportEventTimeElemnt()
            let end = origin.end?.supportEventTimeElemnt()
            
            switch (start, end) {
            case (.period(let st), .period(let et)):
                self.eventTime = .period(
                    st.timeIntervalSince1970..<et.timeIntervalSince1970
                )
            case (.allDay(let st, let sz), .allDay(let et, _)):
                self.eventTime = .allDay(
                    st.timeIntervalSince1970..<et.timeIntervalSince1970,
                    secondsFromGMT: TimeInterval(sz.secondsFromGMT())
                )
            default:
                return nil
            }
        }
    }
}

extension GoogleCalendar.EventRawValue.GoogleEventTime {
    
    enum SupportEventTimeElemnt {
        case period(Date)
        case allDay(Date, TimeZone)
    }
    
    func supportEventTimeElemnt() -> SupportEventTimeElemnt? {
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if
            let date = self.date.flatMap ({ formatter.date(from: $0) }),
            let timeZone = self.timeZone.flatMap ({ TimeZone(identifier: $0) })
        {
            return .allDay(date, timeZone)
        } else if let dateTime = self.dateTime.flatMap({ formatter.date(from: $0) }) {
            return .period(dateTime)
        } else {
            return nil
        }
    }
}
