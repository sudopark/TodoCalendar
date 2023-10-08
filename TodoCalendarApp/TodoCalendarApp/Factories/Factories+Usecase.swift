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
    
    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase {
        let settingRepository = CalendarSettingRepositoryImple(
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return CalendarSettingUsecaseImple(
            settingRepository: settingRepository,
            shareDataStore: Singleton.shared.sharedDataStore
        )
    }
    
    func makeHolidayUsecase() -> any HolidayUsecase {
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
    
    func makeCalendarUsecase() -> any CalendarUsecase {
        return CalendarUsecaseImple(
            calendarSettingUsecase: self.makeCalendarSettingUsecase(),
            holidayUsecase: self.makeHolidayUsecase()
        )
    }
}


extension NonLoginUsecaseFactoryImple {
    
    func makeTodoEventUsecase() -> any TodoEventUsecase {
            
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
    
    func makeScheduleEventUsecase() -> any ScheduleEventUsecase {
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
    
    private func makeEventTagRepository() -> any EventTagRepository {
        let storage = EventTagLocalStorage(
            sqliteService: Singleton.shared.commonSqliteService
        )
        let repository = EventTagLocalRepositoryImple(
            localStorage: storage,
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return repository
    }
    
    func makeEventTagUsecase() -> any EventTagUsecase {
        return EventTagUsecaseImple(
            tagRepository: self.makeEventTagRepository(),
            sharedDataStore: Singleton.shared.sharedDataStore
        )
    }
}


extension NonLoginUsecaseFactoryImple {
    
    func makeUISettingUsecase() -> any UISettingUsecase {
        let repository = AppSettingRepositoryImple(
            environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
        )
        return UISettingUsecaseImple(appSettingRepository: repository)
    }
}
