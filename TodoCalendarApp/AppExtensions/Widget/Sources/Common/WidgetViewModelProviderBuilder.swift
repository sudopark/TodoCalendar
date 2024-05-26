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

final class WidgetBase {
    static let shared: WidgetBase = .init()
    private init() { }
    
    // TOOD: app group으로 변경해야함
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple()
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        return service
    }()
}


struct WidgetViewModelProviderBuilder {
    
    private static func makeHolidayRepository(_ base: WidgetBase) -> HolidayRepositoryImple {
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
    
    static func makeMonthViewModelProvider() -> MonthWidgetViewModelProvider{
        let base = WidgetBase.shared
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
