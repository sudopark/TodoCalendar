//
//  EventSettings.swift
//  Domain
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


// MARK: - EventSettings

public struct EventSettings: Sendable, Equatable {
    
    public enum DefaultNewEventPeriod: String, Sendable {
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
    
    public var defaultNewEventTagId: EventTagId = .default
    public var defaultNewEventPeriod: DefaultNewEventPeriod = .minute0
    
    public init() { }
    
    public func update(_ params: EditEventSettingsParams) -> EventSettings {
        let newSetting = self
            |> \.defaultNewEventTagId .~ (params.defaultNewEventTagId ?? self.defaultNewEventTagId)
            |> \.defaultNewEventPeriod .~ (params.defaultNewEventPeriod ??  self.defaultNewEventPeriod)
        return newSetting
    }
}


// MARK: - EditEventSettingsParams

public struct EditEventSettingsParams: Sendable, Equatable {
    
    public var defaultNewEventTagId: EventTagId?
    public var defaultNewEventPeriod: EventSettings.DefaultNewEventPeriod?
    
    public init() { }
    
    public var isValid: Bool {
        return self.defaultNewEventTagId != nil
            || self.defaultNewEventPeriod != nil
    }
}
