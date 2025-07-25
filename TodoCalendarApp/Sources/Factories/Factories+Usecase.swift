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
    let externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    let viewAppearanceStore: ApplicationViewAppearanceStoreImple
    private let applicationBase: ApplicationBase
    
    init(
        authUsecase: any AuthUsecase,
        accountUescase: any AccountUsecase,
        externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        viewAppearanceStore: ApplicationViewAppearanceStoreImple,
        applicationBase: ApplicationBase
    ) {
        self.authUsecase = authUsecase
        self.accountUescase = accountUescase
        self.externalCalenarIntegrationUsecase = externalCalenarIntegrationUsecase
        self.viewAppearanceStore = viewAppearanceStore
        self.applicationBase = applicationBase
    }
    
    var eventNotifyService: SharedEventNotifyService {
        return self.applicationBase.eventNotifyService
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
            sharedDataStore: applicationBase.sharedDataStore,
            eventNotifyService: applicationBase.eventNotifyService
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
            sharedDataStore: applicationBase.sharedDataStore,
            eventNotifyService: applicationBase.eventNotifyService
        )
    }
    
    private func makeEventTagRepository() -> any EventTagRepository {
        let storage = EventTagLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let todoLocal = TodoLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        let scheduleLocal = ScheduleEventLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        let repository = EventTagLocalRepositoryImple(
            localStorage: storage,
            todoLocalStorage: todoLocal,
            scheduleLocalStorage: scheduleLocal,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return repository
    }
    
    func makeEventTagUsecase() -> any EventTagUsecase {
        return EventTagUsecaseImple(
            tagRepository: self.makeEventTagRepository(),
            todoEventusecase: self.makeTodoEventUsecase(),
            scheduleEventUsecase: self.makeScheduleEventUsecase(),
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
            sharedDataStore: applicationBase.sharedDataStore,
            eventNotifyService: applicationBase.eventNotifyService
        )
    }
}


extension NonLoginUsecaseFactoryImple {
    
    func makeEventNotificationUsecase() -> any EventNotificationUsecase {
        let notificaitonRepository = EventNotificationRepositoryImple(
            sqliteService: applicationBase.commonSqliteService,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return EventNotificationUsecaseImple(
            todoEventUsecase: self.makeTodoEventUsecase(),
            scheduleEventUescase: self.makeScheduleEventUsecase(),
            notificationRepository: notificaitonRepository
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

extension NonLoginUsecaseFactoryImple {
    
    func makeLinkPreviewFetchUsecase() -> any LinkPreviewFetchUsecase {
        return LinkPreviewFetchUsecaesImple(
            previewEngine: applicationBase.linkPreviewEngine
        )
    }
}

extension NonLoginUsecaseFactoryImple {
    
    func makeFeedbackUsecase() -> any FeedbackUsecase {
        let feedbackRepository = FeedbackRepositoryImple(remote: self.applicationBase.remoteAPI)
        return FeedbackUsecaseImple(
            accountUsecase: self.accountUescase,
            feedbackRepository: feedbackRepository,
            deviceInfoFetchService: DeviceInfoFetchServiceImple()
        )
    }
}

extension NonLoginUsecaseFactoryImple {
    
    func makeGoogleCalendarUsecase() -> any GoogleCalendarUsecase {
        let cacheStorage = GoogleCalendarLocalStorageImple(
            sqliteService: self.applicationBase.commonSqliteService
        )
        let repository = GoogleCalendarRepositoryImple(
            remote: self.applicationBase.googleCalendarRemoteAPI,
            cacheStorage: cacheStorage
        )
        return GoogleCalendarUsecaseImple(
            googleService: AppEnvironment.googleCalendarService,
            repository: repository,
            eventTagUsecase: self.makeEventTagUsecase(),
            appearanceStore: self.viewAppearanceStore,
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }
}


// MARK: - LoginUsecaseFactoryImple


struct LoginUsecaseFactoryImple: UsecaseFactory {
    
    let userId: String
    let authUsecase: any AuthUsecase
    let accountUescase: any AccountUsecase
    let externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    let viewAppearanceStore: ApplicationViewAppearanceStoreImple
    let temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase
    private let applicationBase: ApplicationBase
    
    init(
        userId: String,
        authUsecase: any AuthUsecase,
        accountUescase: any AccountUsecase,
        externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        viewAppearanceStore: ApplicationViewAppearanceStoreImple,
        temporaryUserDataFilePath: String,
        applicationBase: ApplicationBase
    ) {
        self.userId = userId
        self.authUsecase = authUsecase
        self.accountUescase = accountUescase
        self.externalCalenarIntegrationUsecase = externalCalenarIntegrationUsecase
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
    
    var eventNotifyService: SharedEventNotifyService {
        return self.applicationBase.eventNotifyService
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
            sharedDataStore: applicationBase.sharedDataStore,
            eventNotifyService: applicationBase.eventNotifyService
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
            sharedDataStore: applicationBase.sharedDataStore,
            eventNotifyService: applicationBase.eventNotifyService
        )
    }
    
    func makeEventTagUsecase() -> any EventTagUsecase {
        let cache = EventTagLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let todoCache = TodoLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let scheduleCache = ScheduleEventLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = EventTagRemoteRepositoryImple(
            remote: applicationBase.remoteAPI,
            cacheStorage: cache,
            todoCacheStorage: todoCache,
            scheduleCacheStorage: scheduleCache,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return EventTagUsecaseImple(
            tagRepository: repository,
            todoEventusecase: self.makeTodoEventUsecase(),
            scheduleEventUsecase: self.makeScheduleEventUsecase(),
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
            sharedDataStore: applicationBase.sharedDataStore,
            eventNotifyService: applicationBase.eventNotifyService
        )
    }
}


extension LoginUsecaseFactoryImple {
    
    func makeEventNotificationUsecase() -> any EventNotificationUsecase {
        let notificaitonRepository = EventNotificationRepositoryImple(
            sqliteService: applicationBase.commonSqliteService,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return EventNotificationUsecaseImple(
            todoEventUsecase: self.makeTodoEventUsecase(),
            scheduleEventUescase: self.makeScheduleEventUsecase(),
            notificationRepository: notificaitonRepository
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


extension LoginUsecaseFactoryImple {
    
    func makeLinkPreviewFetchUsecase() -> any LinkPreviewFetchUsecase {
        return LinkPreviewFetchUsecaesImple(
            previewEngine: applicationBase.linkPreviewEngine
        )
    }
}

extension LoginUsecaseFactoryImple {
    
    func makeFeedbackUsecase() -> any FeedbackUsecase {
        let feedbackRepository = FeedbackRepositoryImple(remote: self.applicationBase.remoteAPI)
        return FeedbackUsecaseImple(
            accountUsecase: self.accountUescase,
            feedbackRepository: feedbackRepository,
            deviceInfoFetchService: DeviceInfoFetchServiceImple()
        )
    }
}


extension LoginUsecaseFactoryImple {
    
    func makeGoogleCalendarUsecase() -> any GoogleCalendarUsecase {
        let cacheStorage = GoogleCalendarLocalStorageImple(
            sqliteService: self.applicationBase.commonSqliteService
        )
        let repository = GoogleCalendarRepositoryImple(
            remote: self.applicationBase.googleCalendarRemoteAPI,
            cacheStorage: cacheStorage
        )
        return GoogleCalendarUsecaseImple(
            googleService: AppEnvironment.googleCalendarService,
            repository: repository,
            eventTagUsecase: self.makeEventTagUsecase(),
            appearanceStore: self.viewAppearanceStore,
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }
}
