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

struct WidgetViewModelProviderBuilder {
    
    private static func checkShouldReset() async {
        // TODO: 백그라운드 진입 timestamp보고 갱신여부 결정
    }
    
    private static func makeHolidayRepository(_ base: WidgetBaseDependency) -> HolidayRepositoryImple {
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
    
    private static func makeHolidaysFetchUsecase(
        _ base: WidgetBaseDependency,
        _ holidayUsecase: HolidayUsecaseImple? = nil
    ) -> HolidaysFetchUsecaseImple {
        let holidayUsecase = holidayUsecase ?? HolidayUsecaseImple(
            holidayRepository: self.makeHolidayRepository(base),
            dataStore: .init(),
            localeProvider: Locale.current
        )
        return HolidaysFetchUsecaseImple(
            holidayUsecase: holidayUsecase,
            cached: FetchCacheStores.shared.holidays
        )
    }
    
    private static func makeEventsFetchUsecase(
        _ base: WidgetBaseDependency,
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
        let holidayFetchUsecase = holidayFetchUsecase ?? makeHolidaysFetchUsecase(base)
        
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
    
    static func makeMonthViewModelProvider() async -> MonthWidgetViewModelProvider {
        await self.checkShouldReset()
        
        let base = WidgetBaseDependency()
        let calendarSettingRepository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let calendarSettingUsecase = CalendarSettingUsecaseImple(
            settingRepository: calendarSettingRepository,
            shareDataStore: .init()
        )
        let holidayUsecase = HolidayUsecaseImple(
            holidayRepository: self.makeHolidayRepository(base),
            dataStore: .init(),
            localeProvider: Locale.current
        )
        let calendarUsecase = CalendarUsecaseImple(
            calendarSettingUsecase: calendarSettingUsecase,
            holidayUsecase: holidayUsecase
        )

        let holidaysFetchUsecase = self.makeHolidaysFetchUsecase(base, holidayUsecase)
        let eventsFetchUsecase = self.makeEventsFetchUsecase(base, holidaysFetchUsecase)
        
        return MonthWidgetViewModelProvider(
            calendarUsecase: calendarUsecase,
            settingRepository: calendarSettingRepository,
            holidayFetchUsecase: holidaysFetchUsecase,
            eventFetchUsecase: eventsFetchUsecase
        )
    }
}
