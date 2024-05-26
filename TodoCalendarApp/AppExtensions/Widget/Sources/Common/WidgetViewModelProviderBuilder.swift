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


struct WidgetViewModelProviderBuilder {
    
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
    
    static func makeMonthViewModelProvider() -> MonthWidgetViewModelProvider {
        let base = WidgetBaseDependency()
        let calendarSettingRepository = CalendarSettingRepositoryImple(
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let calendarSettingUsecase = CalendarSettingUsecaseImple(
            settingRepository: calendarSettingRepository,
            shareDataStore: .init()
        )
        let holidayReposiotry = self.makeHolidayRepository(base)
        let holidayUsecase = HolidayUsecaseImple(
            holidayRepository: holidayReposiotry,
            dataStore: .init(),
            localeProvider: Locale.current
        )
        let calendarUsecase = CalendarUsecaseImple(
            calendarSettingUsecase: calendarSettingUsecase,
            holidayUsecase: holidayUsecase
        )

        let todoRepository = TodoLocalRepositoryImple(
            localStorage: TodoLocalStorageImple(sqliteService: base.commonSqliteService),
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let scheduleEventRepository = ScheduleEventLocalRepositoryImple(
            localStorage: ScheduleEventLocalStorageImple(sqliteService: base.commonSqliteService),
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        
        return .init(
            calendarUsecase: calendarUsecase,
            holidayUsecase: holidayUsecase,
            settingRepository: calendarSettingRepository,
            todoRepository: todoRepository,
            scheduleRepository: scheduleEventRepository
        )
    }
}
