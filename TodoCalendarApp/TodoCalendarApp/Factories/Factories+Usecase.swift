//
//  Factories+Usecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Repository
import Scenes


// MARK: - NonLoginUsecaseFactoryImple

struct NonLoginUsecaseFactoryImple: UsecaseFactory { }

extension NonLoginUsecaseFactoryImple {
    
    func makeCalendarSettingUsecase() -> CalendarSettingUsecase {
        let settingRepository = CalendarSettingRepositoryImple(
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return CalendarSettingUsecaseImple(
            settingRepository: settingRepository,
            shareDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeHolidayUsecase() -> HolidayUsecase {
        let holidayRepository = HolidayRepositoryImple(
            localEnvironmentStorage: Singleton.shared.userDefaultEnvironmentStorage,
            sqliteService: Singleton.shared.commonSqliteService,
            remoteAPI: Singleton.shared.remoteAPI
        )
        return HolidayUsecaseImple(
            holidayRepository: holidayRepository,
            dataStore: Singleton.shared.sharedDataStore,
            localeProvider: Locale.current
        )
    }
    
    func makeCalendarUsecase() -> CalendarUsecase {
        return CalendarUsecaseImple(
            calendarSettingUsecase: self.makeCalendarSettingUsecase(),
            holidayUsecase: self.makeHolidayUsecase()
        )
    }
}


extension NonLoginUsecaseFactoryImple {
    
    func makeTodoEventUsecase() -> TodoEventUsecase {
            
        let storage = TodoLocalStorage(
            sqliteService: Singleton.shared.commonSqliteService
        )
        let repository = TodoLocalRepositoryImple(
            localStorage: storage
        )
        return TodoEventUsecaseImple(
            todoRepository: repository,
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeScheduleEventUsecase() -> ScheduleEventUsecase {
        let storage = ScheduleEventLocalStorage(
            sqliteService: Singleton.shared.commonSqliteService
        )
        let repository = ScheduleEventLocalRepositoryImple(
            localStorage: storage
        )
        return ScheduleEventUsecaseImple(
            scheduleRepository: repository,
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeEventTagUsecase() -> EventTagUsecase {
        let storage = EventTagLocalStorage(
            sqliteService: Singleton.shared.commonSqliteService
        )
        let repository = EventTagLocalRepositoryImple(
            localStorage: storage
        )
        return EventTagUsecaseImple(
            tagRepository: repository,
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
}