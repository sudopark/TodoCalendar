//
//  WidgetTimelineProviderBuilder.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/25/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository
import SQLiteService
import Alamofire


// MARK: - WidgetBaseDependency

final class WidgetBaseDependency {
    
    init() { }
    
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple(
        suiteName: AppEnvironment.groupID
    )
    
    let keyChainStorage: KeyChainStorageImple = {
        let store = KeyChainStorageImple(identifier: AppEnvironment.keyChainStoreName)
        store.setupSharedGroup(AppEnvironment.groupID)
        return store
    }()
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        let userId = self.keyChainStorage.loadCurrentAuth()?.uid
        let path = AppEnvironment.dbFilePath(for: userId)
        _ = service.open(path: path)
        return service
    }()
}


final class FetchCacheStores {
    let holidays: HolidaysFetchCacheStore = .init()
    let events: CalendarEventsFetchCacheStore = .init()
    private init() { }
    static let shared: FetchCacheStores = .init()
    
    func reset() async {
        await self.holidays.reset()
        await self.events.reset()
    }
}


// MARK: - WidgetViewModelProviderBuilder

struct WidgetViewModelProviderBuilder {
    
    private let base: WidgetBaseDependency
    init(base: WidgetBaseDependency) {
        self.base = base
    }
    
    private func checkShouldReset() async {
        // TODO: 백그라운드 진입 timestamp보고 갱신여부 결정
    }
}


// MARK: - make monthWidgetViewModel

extension WidgetViewModelProviderBuilder {
    
    func makeMonthViewModelProvider() async -> MonthWidgetViewModelProvider {
        await self.checkShouldReset()
        
        let calendarSettingRepository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let calendarSettingUsecase = CalendarSettingUsecaseImple(
            settingRepository: calendarSettingRepository,
            shareDataStore: .init()
        )
        let holidayUsecase = HolidayUsecaseImple(
            holidayRepository: self.makeHolidayRepository(),
            dataStore: .init(),
            localeProvider: Locale.current
        )
        let calendarUsecase = CalendarUsecaseImple(
            calendarSettingUsecase: calendarSettingUsecase,
            holidayUsecase: holidayUsecase
        )

        let holidaysFetchUsecase = self.makeHolidaysFetchUsecase(holidayUsecase)
        let eventsFetchUsecase = self.makeEventsFetchUsecase(holidaysFetchUsecase)
        
        return MonthWidgetViewModelProvider(
            calendarUsecase: calendarUsecase,
            settingRepository: calendarSettingRepository,
            holidayFetchUsecase: holidaysFetchUsecase,
            eventFetchUsecase: eventsFetchUsecase
        )
    }
}


// MARK: - make event list widget viewModel

extension WidgetViewModelProviderBuilder {
    
    func makeEventListViewModelProvider() async -> EventListWidgetViewModelProvider {
        
        await self.checkShouldReset()
        
        let fetchUsecase = self.makeEventsFetchUsecase()
        
        let appSettingRepository = AppSettingLocalRepositoryImple(
            storage: AppSettingLocalStorage(
                environmentStorage: base.userDefaultEnvironmentStorage
            )
        )
        
        let calendarSettingRepository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        
        return EventListWidgetViewModelProvider(
            eventsFetchUsecase: fetchUsecase, 
            appSettingRepository: appSettingRepository,
            calendarSettingRepository: calendarSettingRepository
        )
    }
}


// MARK: - common

extension WidgetViewModelProviderBuilder {
    
    private func makeHolidayRepository() -> HolidayRepositoryImple {
        let remote = RemoteAPIImple(
            environment: .init(calendarAPIHost: ""),
            authenticator: nil
        )
        let repository = HolidayRepositoryImple(
            localEnvironmentStorage: base.userDefaultEnvironmentStorage,
            sqliteService: base.commonSqliteService,
            remoteAPI: remote
        )
        return repository
    }
    
    private func makeHolidaysFetchUsecase(
        _ holidayUsecase: HolidayUsecaseImple? = nil
    ) -> HolidaysFetchUsecaseImple {
        let holidayUsecase = holidayUsecase ?? HolidayUsecaseImple(
            holidayRepository: self.makeHolidayRepository(),
            dataStore: .init(),
            localeProvider: Locale.current
        )
        return HolidaysFetchUsecaseImple(
            holidayUsecase: holidayUsecase,
            cached: FetchCacheStores.shared.holidays
        )
    }
    
    private func makeEventsFetchUsecase(
        _ holidayFetchUsecase: HolidaysFetchUsecaseImple? = nil
    ) -> CalendarEventFetchUsecaseImple {
        
        let todoLocalStorage = TodoLocalStorageImple(sqliteService: base.commonSqliteService)
        let todoRepository = TodoLocalRepositoryImple(
            localStorage: todoLocalStorage, environmentStorage: base.userDefaultEnvironmentStorage
        )
        
        let scheduleStorage = ScheduleEventLocalStorageImple(sqliteService: base.commonSqliteService)
        let scheduleRepository = ScheduleEventLocalRepositoryImple(
            localStorage: scheduleStorage, environmentStorage: base.userDefaultEnvironmentStorage
        )
        let holidayFetchUsecase = holidayFetchUsecase ?? makeHolidaysFetchUsecase()
        
        let eventTagStorage = EventTagLocalStorageImple(sqliteService: base.commonSqliteService)
        let eventTagRepository = EventTagLocalRepositoryImple(
            localStorage: eventTagStorage, environmentStorage: base.userDefaultEnvironmentStorage
        )
        
        return CalendarEventFetchUsecaseImple(
            todoRepository: todoRepository,
            scheduleRepository: scheduleRepository,
            holidayFetchUsecase: holidayFetchUsecase,
            eventTagRepository: eventTagRepository,
            cached: FetchCacheStores.shared.events
        )
    }
}
