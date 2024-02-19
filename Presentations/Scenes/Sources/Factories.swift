//
//  Factories.swift
//  Scenes
//
//  Created by sudo.park on 2023/08/01.
//

import Foundation
import Domain

// MARK: - Usecase Factory

public protocol AuthUsecaseFactory {
    
    var authUsecase: any AuthUsecase { get }
}

public protocol CalendarUsecaseFactory {
    
    func makeCalendarUsecase() -> any CalendarUsecase
    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase
    func makeHolidayUsecase() -> any HolidayUsecase
}

public protocol EventUsecaseFactory {
 
    func makeTodoEventUsecase() -> any TodoEventUsecase
    func makeScheduleEventUsecase() -> any ScheduleEventUsecase
    func makeEventTagUsecase() -> any EventTagUsecase
    func makeEventDetailDataUsecase() -> any EventDetailDataUsecase
}

public protocol SettingUsecaseFactory {
    
    func makeUISettingUsecase() -> any UISettingUsecase
    func makeEventSettingUsecase() -> any EventSettingUsecase
    func makeNotificationPermissionUsecase() -> any NotificationPermissionUsecase
    func makeEventNotificationSettingUsecase() -> any EventNotificationSettingUsecase
}

public protocol UsecaseFactory: AuthUsecaseFactory, CalendarUsecaseFactory, EventUsecaseFactory, SettingUsecaseFactory { }
