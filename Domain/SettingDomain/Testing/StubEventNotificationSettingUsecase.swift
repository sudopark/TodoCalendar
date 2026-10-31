//
//  StubEventNotificationSettingUsecase.swift
//  SettingDomainTesting
//
//  Created by sudo.park on 1/21/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import EventDomainInterface
import SettingDomainInterface


open class StubEventNotificationSettingUsecase: EventNotificationSettingUsecase, @unchecked Sendable {
    
    private var defaultOption: EventNotificationTimeOption?
    private var defaultOptionForAllDay: EventNotificationTimeOption?
    
    public init () { }
    
    open func availableTimes(forAllDay: Bool) -> [EventNotificationTimeOption] {
        let minutes: TimeInterval = 60
        let hours: TimeInterval = 3600
        let days: TimeInterval = 3600 * 24
        return forAllDay
        ? [.allDay9AM, .allDay12AM, .allDay9AMBefore(seconds: days), .allDay9AMBefore(seconds: days*2), .allDay9AMBefore(seconds: days*7)]
        : [
            .atTime,
            .before(seconds: minutes), .before(seconds: minutes*5), .before(seconds: minutes*10),
            .before(seconds: minutes*15), .before(seconds: minutes*30),
            .before(seconds: hours), .before(seconds: hours*2),
            .before(seconds: days), .before(seconds: days*2), .before(seconds: days*7)
        ]
    }
    
    open func loadDefailtNotificationTimeOption(forAllDay: Bool) -> EventNotificationTimeOption? {
        return forAllDay ? self.defaultOptionForAllDay : self.defaultOption
    }
    
    open func saveDefaultNotificationTimeOption(forAllDay: Bool, option: EventNotificationTimeOption?) {
        if forAllDay {
            self.defaultOptionForAllDay = option
        } else {
            self.defaultOption = option
        }
    }
}
