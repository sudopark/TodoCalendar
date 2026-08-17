//
//  AppleCalendarEventEditParams.swift
//  Domain
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

extension AppleCalendar {

    public struct EventEditParams: Sendable, Equatable {

        public var name: String?
        public var time: EventTime?
        public var location: String?
        public var url: String?
        public var notes: String?

        public init() { }

        public var isEmpty: Bool {
            return self.name == nil
                && self.time == nil
                && self.location == nil
                && self.url == nil
                && self.notes == nil
        }
    }

    public enum EventEditScope: Sendable, Equatable {
        case thisEventOnly
        case thisAndFuture
    }
}
