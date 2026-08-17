//
//  GoogleCalendarEventEditParams.swift
//  Domain
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

extension GoogleCalendar {

    public struct EventEditParams: Sendable, Equatable {

        public var summary: String?
        public var start: EventOrigin.GoogleEventTime?
        public var end: EventOrigin.GoogleEventTime?
        public var location: String?
        public var description: String?
        public var colorId: String?
        public var recurrence: [String]?

        public init() { }

        public var isEmpty: Bool {
            return self.summary == nil
                && self.start == nil
                && self.end == nil
                && self.location == nil
                && self.description == nil
                && self.colorId == nil
                && self.recurrence == nil
        }
    }

    public enum EventRemoveScope: Sendable, Equatable {
        case thisEventOnly
        case allEvents
    }
}
