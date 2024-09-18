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
    
    private let base: AppExtensionBase
    private let usecaseFactory: WidgetUsecaseFactory
    init(base: AppExtensionBase) {
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
    
    func makeMonthViewModelProvider(
        shouldSkipCheckCacheReset: Bool = false,
        calendarSettingRepository: (any CalendarSettingRepository)? = nil
    ) async -> MonthWidgetViewModelProvider {
        await self.checkShouldReset()
        
        let calendarSettingRepository = calendarSettingRepository ?? CalendarSettingRepositoryImple(
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
    
    func makeDoubleMonthViewModelProvider() async -> DoubleMonthWidgetViewModelProvider {
        let repository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let provider = await self.makeMonthViewModelProvider(
            calendarSettingRepository: repository
        )
        return DoubleMonthWidgetViewModelProvider(
            settingRepository: repository, monthViewModelProvider: provider
        )
    }
}


// MARK: - make event list widget viewModel

extension WidgetViewModelProviderBuilder {
    
    func makeEventListViewModelProvider(
        shouldSkipCheckCacheReset: Bool = false,
        targetEventTagId: AllEventTagId
    ) async -> EventListWidgetViewModelProvider {
        
        if !shouldSkipCheckCacheReset {
            await self.checkShouldReset()
        }
        
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
            targetEventTagId: targetEventTagId,
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
    
    func makeForemostEventWidgetViewModelProvider() async -> ForemostEventWidgetViewModelProvider {
        
        await self.checkShouldReset()
        
        let appSettingRepository = AppSettingLocalRepositoryImple(
            storage: AppSettingLocalStorage(
                environmentStorage: base.userDefaultEnvironmentStorage
            )
        )
        
        let calendarSettingRepository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        
        let holidayUsecase = HolidayUsecaseImple(
            holidayRepository: self.usecaseFactory.makeHolidayRepository(),
            dataStore: .init(),
            localeProvider: Locale.current
        )
        let holidayFetchUsecase = self.usecaseFactory.makeHolidaysFetchUsecase(holidayUsecase)
        let eventFetchUsecase = self.usecaseFactory.makeEventsFetchUsecase(holidayFetchUsecase)
        
        return ForemostEventWidgetViewModelProvider(
            eventFetchUsecase: eventFetchUsecase,
            calendarSettingRepository: calendarSettingRepository,
            appSettingRepository: appSettingRepository
        )
    }
}


// MARK: - composed

extension WidgetViewModelProviderBuilder {
    
    func makeEventAndMonthWidgetViewModelProvider(
        targetEventTagId: AllEventTagId
    ) async -> EventAndMonthWidgetViewModelProvider {
        
        await self.checkShouldReset()
        
        let eventList = await self.makeEventListViewModelProvider(
            shouldSkipCheckCacheReset: true,
            targetEventTagId: targetEventTagId
        )
        
        let month = await self.makeMonthViewModelProvider(
            shouldSkipCheckCacheReset: true
        )

        return EventAndMonthWidgetViewModelProvider(
            eventListViewModelProvider: eventList, 
            monthViewModelProvider: month
        )
    }
    
    func makeTodayAndMonthWidgetViewModelProvider() async -> TodayAndMonthWidgetViewModelProvider {
        
        await self.checkShouldReset()
        
        let today = await self.makeTodayViewModelProvider()
        
        let month = await self.makeMonthViewModelProvider(
            shouldSkipCheckCacheReset: true
        )

        return TodayAndMonthWidgetViewModelProvider(
            todayViewModelProvider: today,
            monthViewModelProvider: month
        )
    }
}
