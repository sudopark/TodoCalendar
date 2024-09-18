//
//  EventNotificationSettingUsecase.swift
//  Domain
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public protocol EventNotificationSettingUsecase: Sendable {
    
    func availableTimes(forAllDay: Bool) -> [EventNotificationTimeOption]
    func loadDefailtNotificationTimeOption(forAllDay: Bool) -> EventNotificationTimeOption?
    func saveDefaultNotificationTimeOption(forAllDay: Bool, option: EventNotificationTimeOption?)
}


public final class EventNotificationSettingUsecaseImple: EventNotificationSettingUsecase {
    
    private let notificationRepository: any EventNotificationRepository
    
    public init(
        notificationRepository: any EventNotificationRepository
    ) {
        self.notificationRepository = notificationRepository
    }
}

extension EventNotificationSettingUsecaseImple {
    
    public func availableTimes(forAllDay: Bool) -> [EventNotificationTimeOption] {
        return forAllDay ? self.optionsForAllDay : self.optionsForNotAllDay
    }
    
    private var minutes: TimeInterval { 60 }
    private var hours: TimeInterval { 3600 }
    private var days: TimeInterval { 3600 * 24 }
    
    private var optionsForAllDay: [EventNotificationTimeOption] {
        return [
            .allDay9AM,
            .allDay12AM,
            .allDay9AMBefore(seconds: self.days),
            .allDay9AMBefore(seconds: self.days*2),
            .allDay9AMBefore(seconds: self.days*7)
        ]
    }
    
    private var optionsForNotAllDay: [EventNotificationTimeOption] {
        return [
            .atTime,
            .before(seconds: self.minutes),
            .before(seconds: self.minutes*5),
            .before(seconds: self.minutes*10),
            .before(seconds: self.minutes*15),
            .before(seconds: self.minutes*30),
            .before(seconds: self.hours),
            .before(seconds: self.hours*2),
            .before(seconds: self.days),
            .before(seconds: self.days*2),
            .before(seconds: self.days*7)
        ]
    }
    
    public func loadDefailtNotificationTimeOption(
        forAllDay: Bool
    ) -> EventNotificationTimeOption? {
        
        return self.notificationRepository.loadDefaultNotificationTimeOption(forAllDay: forAllDay)
    }
    
    public func saveDefaultNotificationTimeOption(
        forAllDay: Bool, 
        option: EventNotificationTimeOption?
    ) {
        self.notificationRepository.saveDefaultNotificationTimeOption(
            forAllday: forAllDay, option: option
        )
    }
}
