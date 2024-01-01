//
//  EventSettings.swift
//  Domain
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - EventSettings

public struct EventSettings: Sendable, Equatable {
    
    public enum DefaultNewEventPeriod: Sendable, Equatable {
        case minute0
        case minute5
        case minute10
        case minute15
        case minute30
        case minute45
        case hour1
        case hour2
        case allDay
    }
    
    public var defaultNewEventTagId: AllEventTagId = .default
    public var defaultNewEventPeriod: DefaultNewEventPeriod = .hour1
    
    public init() { }
}


// MARK: - EditEventSettingsParams

public struct EditEventSettingsParams: Sendable, Equatable {
    
    public var defaultNewEventTagId: AllEventTagId?
    public var defaultNewEventPeriod: EventSettings.DefaultNewEventPeriod?
    
    public init() { }
    
    public var isValid: Bool {
        return self.defaultNewEventTagId != nil
            || self.defaultNewEventPeriod != nil
    }
}
