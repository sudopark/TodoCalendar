//
//  EventNotificationSettingUsecase.swift
//  SettingDomainInterface
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import EventDomainInterface

public protocol EventNotificationSettingUsecase: Sendable {
    
    func availableTimes(forAllDay: Bool) -> [EventNotificationTimeOption]
    func loadDefailtNotificationTimeOption(forAllDay: Bool) -> EventNotificationTimeOption?
    func saveDefaultNotificationTimeOption(forAllDay: Bool, option: EventNotificationTimeOption?)
}
