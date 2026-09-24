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

    private let eventFactory: NonLoginEventFactory
    private let calendarFactory: CalendarFactory
    private let notificationFactory: NonLoginNotificationFactory
    private let settingFactory: NonLoginSettingFactory
    private let commonFactory: CommonFactory
    private let supportFactory: SupportFactory
    private let speechFactory: SpeechFactory
    private let externalCalendarFactory: NonLoginExternalCalendarFactory

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
        let billingUsecase = NotNeedBillingUsecase(sharedDataStore: applicationBase.sharedDataStore)
        self.billingUsecase = billingUsecase
        self.aiAgentOrchestrationUsecase = NotNeedAIAgentOrchestrationUsecase()

        let eventFactory = NonLoginEventFactory(applicationBase: applicationBase)
        self.eventFactory = eventFactory
        self.calendarFactory = CalendarFactory(applicationBase: applicationBase)
        self.notificationFactory = NonLoginNotificationFactory(
            applicationBase: applicationBase, eventFactory: eventFactory
        )
        self.settingFactory = NonLoginSettingFactory(
            applicationBase: applicationBase, viewAppearanceStore: viewAppearanceStore
        )
        self.commonFactory = CommonFactory(applicationBase: applicationBase)
        self.supportFactory = SupportFactory(
            applicationBase: applicationBase, accountUsecase: accountUescase
        )
        self.speechFactory = SpeechFactory()
        self.externalCalendarFactory = NonLoginExternalCalendarFactory(
            applicationBase: applicationBase,
            eventFactory: eventFactory,
            viewAppearanceStore: viewAppearanceStore,
            externalCalenarIntegrationUsecase: externalCalenarIntegrationUsecase
        )

        self.eventLiveActivityUsecase = EventLiveActivityUsecaseImple(
            controller: EventCountdownLiveActivityController(),
            sharedDataStore: applicationBase.sharedDataStore,
            eventDetailDataUsecase: eventFactory.makeEventDetailDataUsecase()
        )
        self.adExposureUsecase = AdExposureUsecaseImple(
            adAvailability: applicationBase.mobileAdService,
            billingUsecase: billingUsecase,
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

    var temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase {
        return NotNeedTemporaryUserDataMigrationUescaseImple()
    }
}


// MARK: - 하위 팩토리 위임

extension NonLoginUsecaseFactoryImple {

    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase {
        return self.calendarFactory.makeCalendarSettingUsecase()
    }

    func makeHolidayUsecase() -> any HolidayUsecase {
        return self.calendarFactory.makeHolidayUsecase()
    }

    func makeCalendarUsecase() -> any CalendarUsecase {
        return self.calendarFactory.makeCalendarUsecase()
    }

    func makeTodoEventUsecase() -> any TodoEventUsecase {
        return self.eventFactory.makeTodoEventUsecase()
    }

    func makeScheduleEventUsecase() -> any ScheduleEventUsecase {
        return self.eventFactory.makeScheduleEventUsecase()
    }

    func makeEventTagUsecase() -> any EventTagUsecase {
        return self.eventFactory.makeEventTagUsecase()
    }

    func makeEventDetailDataUsecase() -> any EventDetailDataUsecase {
        return self.eventFactory.makeEventDetailDataUsecase()
    }

    func makeDoneTodoDetailDataUsecase() -> any EventDetailDataUsecase {
        return self.eventFactory.makeDoneTodoDetailDataUsecase()
    }

    func makeDoneTodoPagingUsecase() -> any DoneTodoEventsPagingUsecase {
        return self.eventFactory.makeDoneTodoPagingUsecase()
    }

    func makeForemostEventUsecase() -> any ForemostEventUsecase {
        return self.eventFactory.makeForemostEventUsecase()
    }

    func makeDDayCandidateUsecase() -> any DDayCandidateUsecase {
        return self.eventFactory.makeDDayCandidateUsecase()
    }

    func makeDaysIntervalCountUsecase() -> any DaysIntervalCountUsecase {
        return self.eventFactory.makeDaysIntervalCountUsecase()
    }

    func makeEventNotificationUsecase() -> any EventNotificationUsecase {
        return self.notificationFactory.makeEventNotificationUsecase()
    }

    func makeUISettingUsecase() -> any UISettingUsecase {
        return self.settingFactory.makeUISettingUsecase()
    }

    func makeWidgetStyleUsecase() -> any WidgetStyleUsecase {
        return self.settingFactory.makeWidgetStyleUsecase()
    }

    func makeEventSettingUsecase() -> any EventSettingUsecase {
        return self.settingFactory.makeEventSettingUsecase()
    }

    func makeEventShareSettingUsecase() -> any EventShareSettingUsecase {
        return self.settingFactory.makeEventShareSettingUsecase()
    }

    func makeNotificationPermissionUsecase() -> any NotificationPermissionUsecase {
        return self.settingFactory.makeNotificationPermissionUsecase()
    }

    func makeEventNotificationSettingUsecase() -> any EventNotificationSettingUsecase {
        return self.settingFactory.makeEventNotificationSettingUsecase()
    }

    func makeLinkPreviewFetchUsecase() -> any LinkPreviewFetchUsecase {
        return self.commonFactory.makeLinkPreviewFetchUsecase()
    }

    func makePlaceSuggestUsecase() -> any PlaceSuggestUsecase {
        return self.commonFactory.makePlaceSuggestUsecase()
    }

    func deviceInfoFetchService() -> any DeviceInfoFetchService {
        return self.commonFactory.deviceInfoFetchService()
    }

    func makeFeedbackUsecase() -> any FeedbackUsecase {
        return self.supportFactory.makeFeedbackUsecase()
    }

    func makeGuideTodoUsecase() -> any GuideTodoUsecase {
        return self.supportFactory.makeGuideTodoUsecase()
    }

    func makeLegalNoticeUsecase() -> any LegalNoticeUsecase {
        return self.supportFactory.makeLegalNoticeUsecase()
    }

    func makeSpeechRecognizeUsecase() -> any SpeechRecognizeUsecase {
        return self.speechFactory.makeSpeechRecognizeUsecase()
    }

    func makeGoogleCalendarUsecase() -> any GoogleCalendarUsecase {
        return self.externalCalendarFactory.makeGoogleCalendarUsecase()
    }

    func makeAppleCalendarUsecase() -> any AppleCalendarUsecase {
        return self.externalCalendarFactory.makeAppleCalendarUsecase()
    }
}



// MARK: - NonLoginEventFactory

private struct NonLoginEventFactory {

    let applicationBase: ApplicationBase

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


// MARK: - NonLoginNotificationFactory

private struct NonLoginNotificationFactory {

    let applicationBase: ApplicationBase
    let eventFactory: NonLoginEventFactory

    func makeEventNotificationUsecase() -> any EventNotificationUsecase {
        let notificaitonRepository = EventNotificationRepositoryImple(
            sqliteService: applicationBase.commonSqliteService,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return EventNotificationUsecaseImple(
            todoEventUsecase: self.eventFactory.makeTodoEventUsecase(),
            scheduleEventUescase: self.eventFactory.makeScheduleEventUsecase(),
            notificationRepository: notificaitonRepository,
            notificationService: UNLocalNotificationServiceImple()
        )
    }
}


// MARK: - NonLoginSettingFactory

private struct NonLoginSettingFactory {

    let applicationBase: ApplicationBase
    let viewAppearanceStore: ApplicationViewAppearanceStoreImple

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

    func makeEventSettingUsecase() -> any EventSettingUsecase {
        return self.makeAppSettingUsecase()
    }

    func makeEventShareSettingUsecase() -> any EventShareSettingUsecase {
        return self.makeAppSettingUsecase()
    }

    func makeNotificationPermissionUsecase() -> any NotificationPermissionUsecase {
        return NotificationPermissionUsecaseImple(
            notificationService: UNLocalNotificationServiceImple()
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





// MARK: - NonLoginExternalCalendarFactory

private struct NonLoginExternalCalendarFactory {

    let applicationBase: ApplicationBase
    let eventFactory: NonLoginEventFactory
    let viewAppearanceStore: ApplicationViewAppearanceStoreImple
    let externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase

    func makeGoogleCalendarUsecase() -> any GoogleCalendarUsecase {
        return GoogleCalendarUsecaseImple(
            googleService: AppEnvironment.googleCalendarService,
            integrationUsecase: self.externalCalenarIntegrationUsecase,
            repositoryPool: self.applicationBase.googleCalendarRepositoryPool,
            eventTagUsecase: self.eventFactory.makeEventTagUsecase(),
            appearanceStore: self.viewAppearanceStore,
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }

    func makeAppleCalendarUsecase() -> any AppleCalendarUsecase {
        return AppleCalendarUsecaseImple(
            appleService: AppEnvironment.appleCalendarService,
            integrationUsecase: self.externalCalenarIntegrationUsecase,
            repository: self.applicationBase.appleCalendarRepository,
            eventTagUsecase: self.eventFactory.makeEventTagUsecase(),
            appearanceStore: self.viewAppearanceStore,
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }
}
