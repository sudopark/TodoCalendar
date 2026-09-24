//
//  Factories+NonLoginUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import FirstPartyServices
import SpeechService
import PlaceService
import Repository
import Scenes

// MARK: - NonLoginUsecaseFactoryImple

struct NonLoginUsecaseFactoryImple: UsecaseFactory {

    let authUsecase: any AuthUsecase
    let accountUescase: any AccountUsecase
    let externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    let viewAppearanceStore: ApplicationViewAppearanceStoreImple
    let eventSyncUsecase: any EventSyncUsecase
    let eventUploadService: any EventUploadService = NotNeedEventUploadService()
    let appUpdateCheckUsecase: any AppUpdateCheckUsecase
    let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    let billingUsecase: any BillingUsecase
    let eventLiveActivityUsecase: any EventLiveActivityUsecase
    let adExposureUsecase: any AdExposureUsecase
    let imageTextRecognizeService: any ImageTextRecognizeService = ImageTextRecognizeServiceImple()
    private let applicationBase: ApplicationBase

    init(
        authUsecase: any AuthUsecase,
        accountUescase: any AccountUsecase,
        externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        viewAppearanceStore: ApplicationViewAppearanceStoreImple,
        appUpdateCheckUsecase: any AppUpdateCheckUsecase,
        applicationBase: ApplicationBase
    ) {
        self.authUsecase = authUsecase
        self.accountUescase = accountUescase
        self.externalCalenarIntegrationUsecase = externalCalenarIntegrationUsecase
        self.viewAppearanceStore = viewAppearanceStore
        self.appUpdateCheckUsecase = appUpdateCheckUsecase
        self.eventSyncUsecase = NotNeedEventSyncUsecase()
        self.applicationBase = applicationBase
        self.billingUsecase = NotNeedBillingUsecase(sharedDataStore: applicationBase.sharedDataStore)

        self.aiAgentOrchestrationUsecase = NotNeedAIAgentOrchestrationUsecase()

        let eventDetailStorage = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: applicationBase.commonSqliteService
        )
        self.eventLiveActivityUsecase = EventLiveActivityUsecaseImple(
            controller: EventCountdownLiveActivityController(),
            sharedDataStore: applicationBase.sharedDataStore,
            eventDetailDataUsecase: EventDetailDataLocalRepostioryImple(
                localStorage: eventDetailStorage
            )
        )
        self.adExposureUsecase = AdExposureUsecaseImple(
            adAvailability: applicationBase.mobileAdService,
            billingUsecase: self.billingUsecase,
            adRepository: AdLocalRepositoryImple(
                environmentStorage: applicationBase.userDefaultEnvironmentStorage
            ),
            coldLaunchHistoryRepository: AppColdLaunchHistoryLocalRepositoryImple(
                environmentStorage: applicationBase.userDefaultEnvironmentStorage
            )
        )
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
            sqliteService: applicationBase.commonSqliteService,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        let todoLocal = TodoLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        let scheduleLocal = ScheduleEventLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        let detailLocal = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = EventTagLocalRepositoryImple(
            localStorage: storage,
            todoLocalStorage: todoLocal,
            scheduleLocalStorage: scheduleLocal,
            eventDetailLocalStorage: detailLocal
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
        let storage = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: applicationBase.commonSqliteService
        )
        return EventDetailDataLocalRepostioryImple(
            localStorage: storage
        )
    }
    
    func makeDoneTodoDetailDataUsecase() -> any EventDetailDataUsecase {
        let storage = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(
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

    func makeDDayCandidateUsecase() -> any DDayCandidateUsecase {
        return DDayCandidateUsecaseImple(
            repository: DDayCandidateLocalRepositoryImple(
                environmentStorage: applicationBase.userDefaultEnvironmentStorage
            ),
            sharedDataStore: applicationBase.sharedDataStore
        )
    }

    func makeDaysIntervalCountUsecase() -> any DaysIntervalCountUsecase {
        let repository = CalendarSettingRepositoryImple(
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        let settingUsecase = CalendarSettingUsecaseImple(
            settingRepository: repository,
            shareDataStore: applicationBase.sharedDataStore
        )
        return DaysIntervalCountUsecaseImple(
            calendarSettingUsecase: settingUsecase
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
            notificationRepository: notificaitonRepository,
            notificationService: UNLocalNotificationServiceImple()
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
    
    func makeWidgetStyleUsecase() -> any WidgetStyleUsecase {
        return WidgetStyleUsecaseImple(
            styleRepository: WidgetStyleLocalRepositoryImple(
                environmentStorage: applicationBase.userDefaultEnvironmentStorage,
                photoDirectory: AppEnvironment.widgetPhotoDirectory
            ),
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
    
    func makeEventSettingUsecase() -> EventSettingUsecase {
        return self.makeAppSettingUsecase()
    }

    func makeEventShareSettingUsecase() -> any EventShareSettingUsecase {
        return self.makeAppSettingUsecase()
    }

    func makeNotificationPermissionUsecase() -> NotificationPermissionUsecase {
        return NotificationPermissionUsecaseImple(
            notificationService: UNLocalNotificationServiceImple()
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
        return LinkPreviewFetchUsecaseImple(
            previewEngine: applicationBase.linkPreviewFetchEngine
        )
    }
    
    func makePlaceSuggestUsecase() -> any PlaceSuggestUsecase {
        return PlaceSuggestUsecaseImple(
            suggestEngine: MapKitBasePlaceSuggestEngineImple()
        )
    }
    
    func deviceInfoFetchService() -> any DeviceInfoFetchService {
        return DeviceInfoFetchServiceImple()
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

    func makeGuideTodoUsecase() -> any GuideTodoUsecase {
        return GuideTodoUsecaseImple(
            repository: GuideTodoLocalRepositoryImple(
                environmentStorage: self.applicationBase.userDefaultEnvironmentStorage
            ),
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }

    func makeLegalNoticeUsecase() -> any LegalNoticeUsecase {
        return LegalNoticeUsecaseImple(
            legalNoticeRepository: LegalNoticeRepositoryImple(
                remoteAPI: self.applicationBase.remoteAPI,
                environmentStorage: self.applicationBase.userDefaultEnvironmentStorage
            )
        )
    }
}

extension NonLoginUsecaseFactoryImple {

    func makeSpeechRecognizeUsecase() -> any SpeechRecognizeUsecase {
        return SpeechRecognizeUsecaseImple(
            service: SpeechRecognizeServiceImple(),
            permissionChecker: SpeechRecognizePermissionCheckerImple()
        )
    }
}

extension NonLoginUsecaseFactoryImple {

    func makeGoogleCalendarUsecase() -> any GoogleCalendarUsecase {
        return GoogleCalendarUsecaseImple(
            googleService: AppEnvironment.googleCalendarService,
            integrationUsecase: self.externalCalenarIntegrationUsecase,
            repositoryPool: self.applicationBase.googleCalendarRepositoryPool,
            eventTagUsecase: self.makeEventTagUsecase(),
            appearanceStore: self.viewAppearanceStore,
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }

    func makeAppleCalendarUsecase() -> any AppleCalendarUsecase {
        return AppleCalendarUsecaseImple(
            appleService: AppEnvironment.appleCalendarService,
            integrationUsecase: self.externalCalenarIntegrationUsecase,
            repository: self.applicationBase.appleCalendarRepository,
            eventTagUsecase: self.makeEventTagUsecase(),
            appearanceStore: self.viewAppearanceStore,
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }
}
