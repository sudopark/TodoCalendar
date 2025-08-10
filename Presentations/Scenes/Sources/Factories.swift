//
//  Factories.swift
//  Scenes
//
//  Created by sudo.park on 2023/08/01.
//

import Foundation
import Domain

// MARK: - Usecase Factory

public protocol AccountUsecaseFactory {
    
    var authUsecase: any AuthUsecase { get }
    var accountUescase: any AccountUsecase { get }
    var externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase { get }
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
    func makeDoneTodoPagingUsecase() -> any DoneTodoEventsPagingUsecase
    func makeForemostEventUsecase() -> any ForemostEventUsecase
    func makeEventSyncUsecase() -> any EventSyncUsecase
}

public protocol SettingUsecaseFactory {
    
    func makeUISettingUsecase() -> any UISettingUsecase
    func makeEventSettingUsecase() -> any EventSettingUsecase
    func makeNotificationPermissionUsecase() -> any NotificationPermissionUsecase
    func makeEventNotificationSettingUsecase() -> any EventNotificationSettingUsecase
    var temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase { get }
}

public protocol NotificationUsecaseFactory {
    
    func makeEventNotificationUsecase() -> any EventNotificationUsecase
}

public protocol CommonUsecaseFactory {
    
    func makeLinkPreviewFetchUsecase() -> any LinkPreviewFetchUsecase
}

public protocol SupportUsecaseFactory {
    
    func makeFeedbackUsecase() -> any FeedbackUsecase
}

public protocol ExternalCalendarUsecaseFactory {
    
    func makeGoogleCalendarUsecase() -> any GoogleCalendarUsecase
}

public protocol UsecaseFactory: AccountUsecaseFactory, CalendarUsecaseFactory, EventUsecaseFactory, NotificationUsecaseFactory, SettingUsecaseFactory, CommonUsecaseFactory, SupportUsecaseFactory, ExternalCalendarUsecaseFactory {
    
    var eventNotifyService: SharedEventNotifyService { get }
}
