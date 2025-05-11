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
        public var colorHex: String? { backgroundColorHex }
        
        public init(id: String, name: String) {
            self.id = id
            self.tagId = .externalCalendar(serviceId: GoogleCalendarService.id, id: id)
            self.name = name
        }
    }
}


// MARK: - event

extension GoogleCalendar {
    
    public struct EventOrigin: Decodable, Sendable {
        public let id: String
        public let summary: String
        public var htmlLink: String?
        public var description: String?
        public var location: String?
        public var colorId: String?
        // 이벤트 생성자
        public var creator: Creator?
        // 이벤트 주최자
        public var organizer: Organizer?
        public var start: GoogleEventTime?
        public var end: GoogleEventTime?
        public var endTimeUnspecified: Bool?
        public var recurrence: [String]?
        public var recurringEventId: String?
        public var sequence: Int?
        // 참석자
        public var attendees: [Attendee]?
        public var hangoutLink: String?
        // 회의 정보
        public var conferenceData: ConferenceData?
        // 첨부파일
        public var attachments: [Attachment]?
        public var eventType: String?
        
        public init(
            id: String, summary: String
        ) {
            self.id = id
            self.summary = summary
        }

        public struct Creator: Codable, Sendable {
            public var id: String?
            public var email: String?
            public var displayName: String?
            public var `self`: Bool?
            
            public init() { }
        }

        public struct Organizer: Codable, Sendable {
            public var id: String?
            public var email: String?
            public var displayName: String?
            public var `self`: Bool?
            
            public init() { }
        }

        public struct GoogleEventTime: Codable, Sendable {
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
            
            public init() { }
        }


        public struct ConferenceData: Codable, Sendable {
            public var entryPoints: [EntryPoint]?
            public var conferenceId: String?
            
            public init() { }


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
        
        public struct Attachment: Codable, Sendable {
            public var fileUrl: String?
            public var title: String?
            public var mimeType: String?
            public var iconLink: String?
            public var fileId: String?
            
            public init() { }
        }
    }
    public struct EventOriginValueList: Decodable, Sendable {
        public var timeZone: String?
        public var items: [EventOrigin] = []
        public var nextPageToken: String?
        
        public init() { }
    }
    
    public struct Event: Sendable {
        public let eventId: String
        public let calendarId: String
        public let name: String
        public var eventTagId: EventTagId?
        public var colorId: String?
        public let eventTime: EventTime
        
        public var nextRepeatingTimes: [RepeatingTimes] = []
        public var repeatingTimeToExcludes: Set<String> = []
        
        public init(
            _ eventId: String, _ calendarId: String,
            name: String,
            colorId: String?,
            time: EventTime
        ) {
            self.eventId = eventId
            self.calendarId = calendarId
            self.eventTagId = .externalCalendar(
                serviceId: GoogleCalendarService.id, id: calendarId
            )
            self.name = name
            self.colorId = colorId
            self.eventTime = time
        }
        
        public init?(
            _ origin: EventOrigin, _ calendarId: String, _ defaultTimeZone: String?
        ) {
            self.eventId = origin.id
            self.calendarId = calendarId
            self.name = origin.summary
            self.eventTagId = .externalCalendar(
                serviceId: GoogleCalendarService.id, id: calendarId
            )
            self.colorId = origin.colorId
            let start = origin.start?.supportEventTimeElemnt(defaultTimeZone)
            let end = origin.end?.supportEventTimeElemnt(defaultTimeZone)
            
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

extension GoogleCalendar.EventOrigin.GoogleEventTime {
    
    enum SupportEventTimeElemnt {
        case period(Date)
        case allDay(Date, TimeZone)
    }
    
    func supportEventTimeElemnt(_ defaultTimeZone: String?) -> SupportEventTimeElemnt? {
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [
            .withFullDate, .withDashSeparatorInDate
        ]
        
        let dateTimeFormatter = ISO8601DateFormatter()
        dateTimeFormatter.formatOptions = [
            .withInternetDateTime
        ]
        
        let timeZone = self.timeZone ?? defaultTimeZone
        
        if
            let timeZone = timeZone.flatMap ({ TimeZone(identifier: $0) }),
            let date = self.date.flatMap ({
                dateFormatter.timeZone = timeZone
                return dateFormatter.date(from: $0)
            })
        {
            return .allDay(date, timeZone)
        } else if let dateTime = self.dateTime.flatMap({ dateTimeFormatter.date(from: $0) }) {
            return .period(dateTime)
        } else {
            return nil
        }
    }
}
