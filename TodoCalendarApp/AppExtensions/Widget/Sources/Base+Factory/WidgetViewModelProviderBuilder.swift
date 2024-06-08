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
