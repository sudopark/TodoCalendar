//
//  GoogleCalenarEventTag.swift
//  Domain
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public struct GoogleCalendarColors: Equatable, Sendable {
    
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
