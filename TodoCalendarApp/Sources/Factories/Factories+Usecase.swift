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
    private let applicationBase: ApplicationBase
    
    init(
        authUsecase: any AuthUsecase,
        accountUescase: any AccountUsecase,
        viewAppearanceStore: any ViewAppearanceStore,
        applicationBase: ApplicationBase
    ) {
        self.authUsecase = authUsecase
        self.accountUescase = accountUescase
        self.viewAppearanceStore = viewAppearanceStore
        self.applicationBase = applicationBase
    }
}

extension NonLoginUsecaseFactoryImple {
    
    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase {
        let settingRepository = CalendarSettingRepositoryImple(
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return CalendarSettingUsecaseImple(
            settingRepository: settingRepository,
            shareDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeHolidayUsecase() -> any HolidayUsecase {
        let holidayRepository = HolidayRepositoryImple(
            localEnvironmentStorage: applicationBase.userDefaultEnvironmentStorage,
            sqliteService: applicationBase.commonSqliteService,
            remoteAPI: applicationBase.remoteAPI
        )
        return HolidayUsecaseImple(
            holidayRepository: holidayRepository,
            dataStore: applicationBase.sharedDataStore,
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
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = TodoLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return TodoEventUsecaseImple(
            todoRepository: repository,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeScheduleEventUsecase() -> any ScheduleEventUsecase {
        let storage = ScheduleEventLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = ScheduleEventLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return ScheduleEventUsecaseImple(
            scheduleRepository: repository,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    private func makeEventTagRepository() -> any EventTagRepository {
        let storage = EventTagLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = EventTagLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return repository
    }
    
    func makeEventTagUsecase() -> any EventTagUsecase {
        return EventTagUsecaseImple(
            tagRepository: self.makeEventTagRepository(),
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeEventDetailDataUsecase() -> any EventDetailDataUsecase {
        let storage = EventDetailDataLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        return EventDetailDataLocalRepostioryImple(
            localStorage: storage
        )
    }
    
    func makeDoneTodoPagingUsecase() -> any DoneTodoEventsPagingUsecase {
        let storage = TodoLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = TodoLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return DoneTodoEventsPagingUsecaseImple(
            pageSize: 100,
            todoRepository: repository
        )
    }
    
    func makeForemostEventUsecase() -> any ForemostEventUsecase {
        let storage = ForemostLocalStorageImple(
            environmentStorage: applicationBase.userDefaultEnvironmentStorage,
            todoStorage: TodoLocalStorageImple(
                sqliteService: applicationBase.commonSqliteService
            ),
            scheduleStorage: ScheduleEventLocalStorageImple(
                sqliteService: applicationBase.commonSqliteService
            )
        )
        let repository = ForemostEventLocalRepositoryImple(
            localStorage: storage
        )
        return ForemostEventUsecaseImple(
            repository: repository,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
}


extension NonLoginUsecaseFactoryImple {
    
    private func makeAppSettingUsecase() -> AppSettingUsecaseImple {
        let repository = AppSettingLocalRepositoryImple(
            storage: .init(environmentStorage: applicationBase.userDefaultEnvironmentStorage)
        )
        return AppSettingUsecaseImple(
            appSettingRepository: repository,
            viewAppearanceStore: self.viewAppearanceStore,
            sharedDataStore: applicationBase.sharedDataStore
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
            sqliteService: applicationBase.commonSqliteService,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return EventNotificationSettingUsecaseImple(
            notificationRepository: repository
        )
    }
    
    var temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase {
        return NotNeedTemporaryUserDataMigrationUescaseImple()
    }
}


// MARK: - LoginUsecaseFactoryImple


struct LoginUsecaseFactoryImple: UsecaseFactory {
    
    let userId: String
    let authUsecase: any AuthUsecase
    let accountUescase: any AccountUsecase
    let viewAppearanceStore: any ViewAppearanceStore
    let temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase
    private let applicationBase: ApplicationBase
    
    init(
        userId: String,
        authUsecase: any AuthUsecase,
        accountUescase: any AccountUsecase,
        viewAppearanceStore: any ViewAppearanceStore,
        temporaryUserDataFilePath: String,
        applicationBase: ApplicationBase
    ) {
        self.userId = userId
        self.authUsecase = authUsecase
        self.accountUescase = accountUescase
        self.viewAppearanceStore = viewAppearanceStore
        self.applicationBase = applicationBase
        
        let migrationRepository = TemporaryUserDataMigrationRepositoryImple(
            tempUserDBPath: temporaryUserDataFilePath, 
            remoteAPI: applicationBase.remoteAPI
        )
        self.temporaryUserDataMigrationUsecase = TemporaryUserDataMigrationUescaseImple(
            migrationRepository: migrationRepository
        )
    }
}

extension LoginUsecaseFactoryImple {
    
    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase {
        let settingRepository = CalendarSettingRepositoryImple(
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return CalendarSettingUsecaseImple(
            settingRepository: settingRepository,
            shareDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeHolidayUsecase() -> any HolidayUsecase {
        let holidayRepository = HolidayRepositoryImple(
            localEnvironmentStorage: applicationBase.userDefaultEnvironmentStorage,
            sqliteService: applicationBase.commonSqliteService,
            remoteAPI: applicationBase.remoteAPI
        )
        return HolidayUsecaseImple(
            holidayRepository: holidayRepository,
            dataStore: applicationBase.sharedDataStore,
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

extension LoginUsecaseFactoryImple {
    
    func makeTodoEventUsecase() -> any TodoEventUsecase {
        let cache = TodoLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = TodoRemoteRepositoryImple(
            remote: applicationBase.remoteAPI,
            cacheStorage: cache
        )
        return TodoEventUsecaseImple(
            todoRepository: repository,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeScheduleEventUsecase() -> any ScheduleEventUsecase {
        let cache = ScheduleEventLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = ScheduleEventRemoteRepositoryImple(
            remote: applicationBase.remoteAPI,
            cacheStore: cache
        )
        return ScheduleEventUsecaseImple(
            scheduleRepository: repository,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeEventTagUsecase() -> any EventTagUsecase {
        let cache = EventTagLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = EventTagRemoteRepositoryImple(
            remote: applicationBase.remoteAPI,
            cacheStorage: cache,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return EventTagUsecaseImple(
            tagRepository: repository,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeEventDetailDataUsecase() -> any EventDetailDataUsecase {
        let cache = EventDetailDataLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        return EventDetailDataRemoteRepostioryImple(
            remoteAPI: applicationBase.remoteAPI,
            cacheStorage: cache
        )
    }
    
    func makeDoneTodoPagingUsecase() -> any DoneTodoEventsPagingUsecase {
        let cache = TodoLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = TodoRemoteRepositoryImple(
            remote: applicationBase.remoteAPI,
            cacheStorage: cache
        )
        return DoneTodoEventsPagingUsecaseImple(
            pageSize: 100,
            todoRepository: repository
        )
    }
    
    func makeForemostEventUsecase() -> any ForemostEventUsecase {
        
        let cache = ForemostLocalStorageImple(
            environmentStorage: applicationBase.userDefaultEnvironmentStorage,
            todoStorage: TodoLocalStorageImple(
                sqliteService: applicationBase.commonSqliteService
            ),
            scheduleStorage: ScheduleEventLocalStorageImple(
                sqliteService: applicationBase.commonSqliteService
            )
        )
        let repository = ForemostEventRemoteRepositoryImple(
            remote: applicationBase.remoteAPI,
            cacheStorage: cache
        )
        return ForemostEventUsecaseImple(
            repository: repository, 
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
}

extension LoginUsecaseFactoryImple {
    
    private func makeAppSettingUsecase() -> AppSettingUsecaseImple {
        let repository = AppSettingRemoteRepositoryImple(
            userId: userId,
            remoteAPI: applicationBase.remoteAPI,
            storage: .init(environmentStorage: applicationBase.userDefaultEnvironmentStorage)
        )
        return AppSettingUsecaseImple(
            appSettingRepository: repository,
            viewAppearanceStore: self.viewAppearanceStore,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeUISettingUsecase() -> any UISettingUsecase {
        return self.makeAppSettingUsecase()
    }
    
    func makeEventSettingUsecase() -> any EventSettingUsecase {
        return self.makeAppSettingUsecase()
    }
    
    func makeNotificationPermissionUsecase() -> any NotificationPermissionUsecase {
        return NotificationPermissionUsecaseImple(
            notificationService: UNUserNotificationCenter.current()
        )
    }
    
    func makeEventNotificationSettingUsecase() -> any EventNotificationSettingUsecase {
        let repository = EventNotificationRepositoryImple(
            sqliteService: applicationBase.commonSqliteService,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return EventNotificationSettingUsecaseImple(
            notificationRepository: repository
        )
    }
}
