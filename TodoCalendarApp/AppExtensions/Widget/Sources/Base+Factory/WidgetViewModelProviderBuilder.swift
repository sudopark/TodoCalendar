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


// MARK: - WidgetViewModelProviderBuilder

struct WidgetViewModelProviderBuilder {
    
    private let base: WidgetBaseDependency
    private let usecaseFactory: WidgetUsecaseFactory
    init(base: WidgetBaseDependency) {
        self.base = base
        self.usecaseFactory = .init(base: base)
    }
    
    private func checkShouldReset() async {
        
        let storage = base.userDefaultEnvironmentStorage
        switch (storage.shouldResetAll, storage.shouldResetCurrentTodo) {
        case (true, _):
            await FetchCacheStores.shared.reset()
            storage.shouldResetAll = false
            storage.shouldResetCurrentTodo = false
            
        case (false, true):
            await FetchCacheStores.shared.resetCurrentTodo()
            storage.shouldResetAll = false
        default: break
        }
    }
}

private extension EnvironmentStorage {
    var shouldResetAll: Bool {
        get {
            return self.load(EnvironmentKeys.needCheckResetWidgetCache.rawValue) ?? false
        }
        set {
            self.update(EnvironmentKeys.needCheckResetWidgetCache.rawValue, newValue)
            self.synchronize()
        }
    }
    
    var shouldResetCurrentTodo: Bool {
        get {
            return self.load(EnvironmentKeys.needCheckResetCurrentTodo.rawValue) ?? false
        }
        set {
            self.update(EnvironmentKeys.needCheckResetCurrentTodo.rawValue, newValue)
            self.synchronize()
        }
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
            holidayRepository: self.usecaseFactory.makeHolidayRepository(),
            dataStore: .init(),
            localeProvider: Locale.current
        )
        let calendarUsecase = CalendarUsecaseImple(
            calendarSettingUsecase: calendarSettingUsecase,
            holidayUsecase: holidayUsecase
        )

        let holidaysFetchUsecase = self.usecaseFactory.makeHolidaysFetchUsecase(holidayUsecase)
        let eventsFetchUsecase = self.usecaseFactory.makeEventsFetchUsecase(holidaysFetchUsecase)
        
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
        
        let fetchUsecase = self.usecaseFactory.makeEventsFetchUsecase()
        
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


// MARK: - make today widget viewModel provider

extension WidgetViewModelProviderBuilder {
    
    func makeTodayViewModelProvider() async -> TodayWidgetViewModelProvider {
        
        await self.checkShouldReset()
        
        
        let fetchUsecase = self.usecaseFactory.makeEventsFetchUsecase()
        let calendarSettingRepository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        
        return TodayWidgetViewModelProvider(
            eventsFetchusecase: fetchUsecase,
            calednarSettingRepository: calendarSettingRepository
        )
    }
}


// MARK: make WeekEventsWidgetViewModelProvider

extension WidgetViewModelProviderBuilder {
    
    func makeWeekEventsWidgetViewModelProvider() async -> WeekEventsWidgetViewModelProvider {
        
        await self.checkShouldReset()
        
        let calendarSettingRepository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let calendarSettingUsecase = CalendarSettingUsecaseImple(
            settingRepository: calendarSettingRepository,
            shareDataStore: .init()
        )
        let holidayUsecase = HolidayUsecaseImple(
            holidayRepository: self.usecaseFactory.makeHolidayRepository(),
            dataStore: .init(),
            localeProvider: Locale.current
        )
        let calendarUsecase = CalendarUsecaseImple(
            calendarSettingUsecase: calendarSettingUsecase,
            holidayUsecase: holidayUsecase
        )
        
        let holidayFetchUsecase = self.usecaseFactory.makeHolidaysFetchUsecase(holidayUsecase)
        let eventFetchUsecase = self.usecaseFactory.makeEventsFetchUsecase(holidayFetchUsecase)
        
        let appSettingRepository = AppSettingLocalRepositoryImple(
            storage: AppSettingLocalStorage(
                environmentStorage: base.userDefaultEnvironmentStorage
            )
        )
        
        return WeekEventsWidgetViewModelProvider(
            calendarUsecase: calendarUsecase,
            eventFetchUsecase: eventFetchUsecase,
            settingRepository: calendarSettingRepository,
            appSettingRepository: appSettingRepository
        )
    }
}
