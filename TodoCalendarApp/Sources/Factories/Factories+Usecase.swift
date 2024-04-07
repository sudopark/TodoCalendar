//
//  Factories+Usecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import UserNotifications
import Domain
import Repository
import Scenes


// MARK: - NonLoginUsecaseFactoryImple

struct NonLoginUsecaseFactoryImple: UsecaseFactory {
    
    let authUsecase: any AuthUsecase
    let accountUescase: any AccountUsecase
    let viewAppearanceStore: any ViewAppearanceStore
    
    init(
        authUsecase: any AuthUsecase,
        accountUescase: any AccountUsecase,
        viewAppearanceStore: any ViewAppearanceStore
    ) {
        self.authUsecase = authUsecase
        self.accountUescase = accountUescase
        self.viewAppearanceStore = viewAppearanceStore
    }
}

extension NonLoginUsecaseFactoryImple {
    
    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase {
        let settingRepository = CalendarSettingRepositoryImple(
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return CalendarSettingUsecaseImple(
            settingRepository: settingRepository,
            shareDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeHolidayUsecase() -> any HolidayUsecase {
        let holidayRepository = HolidayRepositoryImple(
            localEnvironmentStorage: Singleton.shared.userDefaultEnvironmentStorage,
            sqliteService: Singleton.shared.commonSqliteService,
            remoteAPI: Singleton.shared.remoteAPI
        )
        return HolidayUsecaseImple(
            holidayRepository: holidayRepository,
            dataStore: Singleton.shared.sharedDataStore,
            localeProvider: Locale.current
        )
    }
    
    func makeCalendarUsecase() -> any CalendarUsecase {
        return CalendarUsecaseImple(
            calendarSettingUsecase: self.makeCalendarSettingUsecase(),
            holidayUsecase: self.makeHolidayUsecase()
        )
    }
}


extension NonLoginUsecaseFactoryImple {
    
    func makeTodoEventUsecase() -> any TodoEventUsecase {
            
        let storage = TodoLocalStorageImple(
            sqliteService: Singleton.shared.commonSqliteService
        )
        let repository = TodoLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return TodoEventUsecaseImple(
            todoRepository: repository,
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeScheduleEventUsecase() -> any ScheduleEventUsecase {
        let storage = ScheduleEventLocalStorageImple(
            sqliteService: Singleton.shared.commonSqliteService
        )
        let repository = ScheduleEventLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return ScheduleEventUsecaseImple(
            scheduleRepository: repository,
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    private func makeEventTagRepository() -> any EventTagRepository {
        let storage = EventTagLocalStorageImple(
            sqliteService: Singleton.shared.commonSqliteService
        )
        let repository = EventTagLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return repository
    }
    
    func makeEventTagUsecase() -> any EventTagUsecase {
        return EventTagUsecaseImple(
            tagRepository: self.makeEventTagRepository(),
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeEventDetailDataUsecase() -> any EventDetailDataUsecase {
        let storage = EventDetailDataLocalStorageImple(
            sqliteService: Singleton.shared.commonSqliteService
        )
        return EventDetailDataLocalRepostioryImple(
            localStorage: storage
        )
    }
}


extension NonLoginUsecaseFactoryImple {
    
    private func makeAppSettingUsecase() -> AppSettingUsecaseImple {
        let repository = AppSettingRepositoryImple(
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return AppSettingUsecaseImple(
            appSettingRepository: repository,
            viewAppearanceStore: self.viewAppearanceStore,
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeUISettingUsecase() -> any UISettingUsecase {
        return self.makeAppSettingUsecase()
    }
    
    func makeEventSettingUsecase() -> EventSettingUsecase {
        return self.makeAppSettingUsecase()
    }
    
    func makeNotificationPermissionUsecase() -> NotificationPermissionUsecase {
        return NotificationPermissionUsecaseImple(
            notificationService: UNUserNotificationCenter.current()
        )
    }
    
    func makeEventNotificationSettingUsecase() -> EventNotificationSettingUsecase {
        let repository = EventNotificationRepositoryImple(
            sqliteService: Singleton.shared.commonSqliteService,
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return EventNotificationSettingUsecaseImple(
            notificationRepository: repository
        )
    }
}
