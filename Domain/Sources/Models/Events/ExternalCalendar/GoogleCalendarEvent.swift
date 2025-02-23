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
