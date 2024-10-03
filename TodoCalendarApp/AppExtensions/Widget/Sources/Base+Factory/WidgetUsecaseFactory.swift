//
//  UsecaseFactory.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


// MARK: - FetchCacheStores

final class FetchCacheStores: Sendable {
    let holidays: HolidaysFetchCacheStore = .init()
    let events: CalendarEventsFetchCacheStore = .init()
    private init() { }
    static let shared: FetchCacheStores = .init()
    
    func reset() async {
        await self.holidays.reset()
        await self.events.reset()
    }
    
    func resetCurrentTodo() async {
        await self.events.resetCurrentTodo()
    }
}


// MARK: - WidgetUsecaseFactory

struct WidgetUsecaseFactory {
    
    private let base: AppExtensionBase
    init(base: AppExtensionBase) {
        self.base = base
    }
}

extension WidgetUsecaseFactory {
    
    func makeHolidayRepository() -> any HolidayRepository {
        let remote = RemoteAPIImple(
            environment: .init(calendarAPIHost: "", csAPI: ""),
            authenticator: nil
        )
        let repository = HolidayRepositoryImple(
            localEnvironmentStorage: base.userDefaultEnvironmentStorage,
            sqliteService: base.commonSqliteService,
            remoteAPI: remote
        )
        return repository
    }
    
    func makeTodoToggleRepository() -> any TodoEventRepository {
        return self.makeTodoRepositoryByUser()
    }
    
    func makeHolidaysFetchUsecase(
        _ holidayUsecase: (any HolidayUsecase)? = nil
    ) -> any HolidaysFetchUsecase {
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
    
    func makeEventsFetchUsecase(
        _ holidayFetchUsecase: (any HolidaysFetchUsecase)? = nil
    ) -> any CalendarEventFetchUsecase {
        
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
        
        let foremostEventLocalStorage = ForemostLocalStorageImple(
            environmentStorage: base.userDefaultEnvironmentStorage,
            todoStorage: todoLocalStorage,
            scheduleStorage: scheduleStorage
        )
        let foremostEventRepository = ForemostEventLocalRepositoryImple(
            localStorage: foremostEventLocalStorage
        )
        
        return CalendarEventFetchUsecaseImple(
            todoRepository: todoRepository,
            scheduleRepository: scheduleRepository,
            foremostEventRepository: foremostEventRepository,
            holidayFetchUsecase: holidayFetchUsecase,
            eventTagRepository: eventTagRepository,
            cached: FetchCacheStores.shared.events
        )
    }
    
    private func makeTodoRepositoryByUser() -> any TodoEventRepository {
        let auth = self.base.authStore.loadCurrentAuth()
        let localStorage = TodoLocalStorageImple(
            sqliteService: base.commonSqliteService
        )
        if let auth {
            let remote = base.remoteAPI
            remote.setup(credential: auth)
            return TodoRemoteRepositoryImple(
                remote: base.remoteAPI,
                cacheStorage: localStorage
            )
        } else {
            return TodoLocalRepositoryImple(
                localStorage: localStorage,
                environmentStorage: base.userDefaultEnvironmentStorage
            )
        }
    }
}
