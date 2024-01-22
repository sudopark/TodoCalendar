//
//  StubEventNotificationSettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 1/21/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubEventNotificationSettingUsecase: EventNotificationSettingUsecase, @unchecked Sendable {
    
    private let privateSettingUsecase: EventNotificationSettingUsecaseImple
    public init () {
        privateSettingUsecase = .init(
            notificationRepository: StubEventNotificationRepository()
        )
    }
    
    open func availableTimes(forAllDay: Bool) -> [EventNotificationTimeOption] {
        return self.privateSettingUsecase.availableTimes(forAllDay: forAllDay)
    }
    
    open func loadDefailtNotificationTimeOption(forAllDay: Bool) -> EventNotificationTimeOption? {
        return self.privateSettingUsecase.loadDefailtNotificationTimeOption(forAllDay: forAllDay)
    }
    
    open func saveDefaultNotificationTimeOption(forAllDay: Bool, option: EventNotificationTimeOption?) {
        return self.privateSettingUsecase.saveDefaultNotificationTimeOption(forAllDay: forAllDay, option: option)
    }
}
