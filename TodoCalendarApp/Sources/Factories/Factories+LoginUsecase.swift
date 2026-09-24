//
//  Factories+LoginUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import FirstPartyServices
import Repository
import StoreKitService
import Scenes

// MARK: - LoginUsecaseFactoryImple

struct LoginUsecaseFactoryImple: UsecaseFactory {

    let userId: String
    let authUsecase: any AuthUsecase
    let accountUescase: any AccountUsecase
    let externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    let viewAppearanceStore: ApplicationViewAppearanceStoreImple
    let temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase
    let eventSyncUsecase: any EventSyncUsecase
    let eventUploadService: any EventUploadService
    let appUpdateCheckUsecase: any AppUpdateCheckUsecase
    let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    let billingUsecase: any BillingUsecase
    let eventLiveActivityUsecase: any EventLiveActivityUsecase
    let adExposureUsecase: any AdExposureUsecase
    let imageTextRecognizeService: any ImageTextRecognizeService = ImageTextRecognizeServiceImple()
    private let applicationBase: ApplicationBase

    private let eventFactory: LoginEventFactory
    private let calendarFactory: CalendarFactory
    private let notificationFactory: LoginNotificationFactory
    private let settingFactory: LoginSettingFactory
    private let commonFactory: CommonFactory
    private let supportFactory: SupportFactory
    private let speechFactory: SpeechFactory
    private let externalCalendarFactory: LoginExternalCalendarFactory

    init(
        userId: String,
        authUsecase: any AuthUsecase,
        accountUescase: any AccountUsecase,
        externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        viewAppearanceStore: ApplicationViewAppearanceStoreImple,
        appUpdateCheckUsecase: any AppUpdateCheckUsecase,
        temporaryUserDataFilePath: String,
        applicationBase: ApplicationBase
    ) {
        self.userId = userId
        self.authUsecase = authUsecase
        self.accountUescase = accountUescase
        self.externalCalenarIntegrationUsecase = externalCalenarIntegrationUsecase
        self.viewAppearanceStore = viewAppearanceStore
        self.appUpdateCheckUsecase = appUpdateCheckUsecase
        self.applicationBase = applicationBase

        let migrationRepository = TemporaryUserDataMigrationRepositoryImple(
            tempUserDBPath: temporaryUserDataFilePath,
            remoteAPI: applicationBase.remoteAPI,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        let migrationUsecase = TemporaryUserDataMigrationUescaseImple(
            migrationRepository: migrationRepository
        )
        self.temporaryUserDataMigrationUsecase = migrationUsecase

        let uploadService = EventUploadServiceImple(
            pendingQueueStorage: EventUploadPendingQueueLocalStorageImple(
                maxFailCount: AppEnvironment.eventUploadMaxFailCount,
                sqliteService: applicationBase.commonSqliteService
            ),
            eventTagRemote: EventTagRemoteImple(remote: applicationBase.remoteAPI),
            eventTagLocalStorage: EventTagLocalStorageImple(
                sqliteService: applicationBase.commonSqliteService,
                environmentStorage: applicationBase.userDefaultEnvironmentStorage
            ),
            todoRemote: TodoRemoteImple(remote: applicationBase.remoteAPI),
            todoLocalStorage: TodoLocalStorageImple(sqliteService: applicationBase.commonSqliteService),
            scheduleRemote: ScheduleEventRemoteImple(remote: applicationBase.remoteAPI),
            scheduleLocalStorage: ScheduleEventLocalStorageImple(sqliteService: applicationBase.commonSqliteService),
            eventDetailRemote: EventDetailRemoteImple(remoteAPI: applicationBase.remoteAPI),
            eventDetailLocalStorage: EventDetailDataLocalStorageImple<EventDetailDataTable>(sqliteService: applicationBase.commonSqliteService),
            doneTodoDetailRemote: EventDetailRemoteImple(remoteAPI: applicationBase.remoteAPI, isDoneTodoDetail: true),
            doneTodoDetailLocalStorage: EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(sqliteService: applicationBase.commonSqliteService)
        )
        self.eventUploadService = uploadService

        let eventFactory = LoginEventFactory(
            applicationBase: applicationBase,
            eventUploadService: uploadService,
            temporaryUserDataMigrationUsecase: migrationUsecase
        )
        let calendarFactory = CalendarFactory(applicationBase: applicationBase)
        let settingFactory = LoginSettingFactory(
            applicationBase: applicationBase,
            userId: userId,
            viewAppearanceStore: viewAppearanceStore
        )
        self.eventFactory = eventFactory
        self.calendarFactory = calendarFactory
        self.settingFactory = settingFactory
        self.notificationFactory = LoginNotificationFactory(
            applicationBase: applicationBase, eventFactory: eventFactory
        )
        self.commonFactory = CommonFactory(applicationBase: applicationBase)
        self.supportFactory = SupportFactory(
            applicationBase: applicationBase, accountUsecase: accountUescase
        )
        let speechFactory = SpeechFactory()
        self.speechFactory = speechFactory
        self.externalCalendarFactory = LoginExternalCalendarFactory(
            applicationBase: applicationBase,
            eventFactory: eventFactory,
            viewAppearanceStore: viewAppearanceStore,
            externalCalenarIntegrationUsecase: externalCalenarIntegrationUsecase
        )

        let eventSyncUsecase = eventFactory.makeEventSyncUsecase()
        self.eventSyncUsecase = eventSyncUsecase

        let aiRepository = AICommandRepositoryImple(
            remote: applicationBase.remoteAPI,
            localStorage: AICommandLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        )
        self.aiAgentOrchestrationUsecase = AIAgentOrchestrationUsecaseImple(
            commandUsecase: AICommandUsecaseImple(
                repository: aiRepository,
                calendarSettingUsecase: calendarFactory.makeCalendarSettingUsecase()
            ),
            usageUsecase: AIAgentUsageUsecaseImple(
                repository: aiRepository,
                sharedDataStore: applicationBase.sharedDataStore
            ),
            speechRecognizeUsecase: speechFactory.makeSpeechRecognizeUsecase(),
            eventSyncUsecase: eventSyncUsecase,
            foremostEventUsecase: eventFactory.makeForemostEventUsecase(),
            notificationPermissionUsecase: settingFactory.makeNotificationPermissionUsecase()
        )

        let billingUsecase = BillingUsecaseImple(
            repository: BillingRepositoryImple(remote: applicationBase.remoteAPI),
            appStoreService: AppStoreBillingServiceImple(),
            sharedDataStore: applicationBase.sharedDataStore
        )
        self.billingUsecase = billingUsecase

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
}


// MARK: - 하위 팩토리 위임

extension LoginUsecaseFactoryImple {

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



// MARK: - LoginEventFactory

private struct LoginEventFactory {

    let applicationBase: ApplicationBase
    let eventUploadService: any EventUploadService
    let temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase

    private func makeTodoRepository() -> any TodoEventRepository {
        let todoRemote = TodoRemoteImple(remote: self.applicationBase.remoteAPI)
        let localRepository = TodoLocalRepositoryImple(
            localStorage: TodoLocalStorageImple(sqliteService: applicationBase.commonSqliteService),
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return TodoUploadDecorateRepositoryImple(
            remote: todoRemote,
            localRepository: localRepository,
            eventUploadService: self.eventUploadService
        )
    }

    func makeTodoEventUsecase() -> any TodoEventUsecase {
        let repository = self.makeTodoRepository()
        return TodoEventUsecaseImple(
            todoRepository: repository,
            sharedDataStore: applicationBase.sharedDataStore,
            eventNotifyService: applicationBase.eventNotifyService
        )
    }

    private func makeScheduleRepository() -> any ScheduleEventRepository {
        let localRepository = ScheduleEventLocalRepositoryImple(
            localStorage: ScheduleEventLocalStorageImple(sqliteService: applicationBase.commonSqliteService),
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return ScheduleEventUploadDecorateRepositoryImple(
            localRepository: localRepository,
            eventUploadService: self.eventUploadService
        )
    }

    func makeScheduleEventUsecase() -> any ScheduleEventUsecase {
        let repository = self.makeScheduleRepository()
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
        let detailLocal = EventDetailDataLocalStorageImple<EventDetailDataTable>(sqliteService: applicationBase.commonSqliteService)
        let localRepository = EventTagLocalRepositoryImple(
            localStorage: storage,
            todoLocalStorage: todoLocal,
            scheduleLocalStorage: scheduleLocal,
            eventDetailLocalStorage: detailLocal
        )
        let remote = EventTagRemoteImple(remote: applicationBase.remoteAPI)
        return EventTagUploadDecorateRepositoryImple(
            localRepository: localRepository,
            eventUploadService: self.eventUploadService,
            remote: remote
        )
    }

    func makeEventTagUsecase() -> any EventTagUsecase {
        let repository = self.makeEventTagRepository()
        return EventTagUsecaseImple(
            tagRepository: repository,
            todoEventusecase: self.makeTodoEventUsecase(),
            scheduleEventUsecase: self.makeScheduleEventUsecase(),
            sharedDataStore: applicationBase.sharedDataStore
        )
    }

    func makeEventDetailDataUsecase() -> any EventDetailDataUsecase {
        let cache = EventDetailDataLocalStorageImple<EventDetailDataTable>(
            sqliteService: applicationBase.commonSqliteService
        )
        let remote = EventDetailRemoteImple(remoteAPI: applicationBase.remoteAPI)
        return EventDetailUploadDecorateRepositoryImple(
            remote: remote,
            cacheStorage: cache,
            uploadService: self.eventUploadService
        )
    }

    func makeDoneTodoDetailDataUsecase() -> any EventDetailDataUsecase {
        let cache = EventDetailDataLocalStorageImple<DoneTodoEventDetailTable>(
            sqliteService: applicationBase.commonSqliteService
        )
        let remote = EventDetailRemoteImple(
            remoteAPI: applicationBase.remoteAPI,
            isDoneTodoDetail: true
        )
        return EventDetailUploadDecorateRepositoryImple(
            remote: remote,
            cacheStorage: cache,
            uploadService: self.eventUploadService
        )
    }

    func makeDoneTodoPagingUsecase() -> any DoneTodoEventsPagingUsecase {
        let cache = TodoLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService
        )
        let repository = TodoRemoteRepositoryImple(
            remote: TodoRemoteImple(remote: applicationBase.remoteAPI),
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

    /// 후보는 로컬(App Group) 전용이라 로그인 여부와 무관하게 같은 조립이다.
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

    func makeEventSyncUsecase() -> any EventSyncUsecase {
        let mediator = EventSyncMediatorImple(
            eventUploadService: self.eventUploadService,
            migrationUsecase: self.temporaryUserDataMigrationUsecase
        )
        let syncTimeLocal = EventSyncTimestampLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        let eventTagLocal = EventTagLocalStorageImple(
            sqliteService: applicationBase.commonSqliteService,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        let todoLocal = TodoLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        let scheduleLocal = ScheduleEventLocalStorageImple(sqliteService: applicationBase.commonSqliteService)
        let repository = EventSyncRepositoryImple(
            remote: self.applicationBase.remoteAPI,
            syncTimestampLocalStorage: syncTimeLocal,
            eventTagLocalStorage: eventTagLocal,
            todoLocalStorage: todoLocal,
            scheduleLocalStorage: scheduleLocal
        )

        return EventSyncUsecaseImple(
            syncRepository: repository, eventSyncMediator: mediator
        )
    }
}


// MARK: - LoginNotificationFactory

private struct LoginNotificationFactory {

    let applicationBase: ApplicationBase
    let eventFactory: LoginEventFactory

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


// MARK: - LoginSettingFactory

private struct LoginSettingFactory {

    let applicationBase: ApplicationBase
    let userId: String
    let viewAppearanceStore: ApplicationViewAppearanceStoreImple

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





// MARK: - LoginExternalCalendarFactory

private struct LoginExternalCalendarFactory {

    let applicationBase: ApplicationBase
    let eventFactory: LoginEventFactory
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
