//
//  IntentReposiotryFactory.swift
//  TodoCalendarAppIntentExtensions
//
//  Created by sudo.park on 7/27/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import Repository

struct IntentReposiotryFactory {
    
    private let base: AppExtensionBase
    init(base: AppExtensionBase) {
        self.base = base
    }
}

extension IntentReposiotryFactory {
    
    func makeEventTagRepository() -> any EventTagRepository {
        
        let auth = self.base.authStore.loadCurrentAuth()
        let localStorage = EventTagLocalStorageImple(sqliteService: base.commonSqliteService)
        let todoLocalStorage = TodoLocalStorageImple(sqliteService: base.commonSqliteService)
        let scheduleLocalStorage = ScheduleEventLocalStorageImple(sqliteService: base.commonSqliteService)
        
        if let auth {
            let remote = base.remoteAPI
            remote.setup(credential: auth)
            return EventTagRemoteRepositoryImple(
                remote: remote,
                cacheStorage: localStorage,
                todoCacheStorage: todoLocalStorage,
                scheduleCacheStorage: scheduleLocalStorage,
                environmentStorage: base.userDefaultEnvironmentStorage
            )
        } else {
            return EventTagLocalRepositoryImple(
                localStorage: localStorage,
                todoLocalStorage: todoLocalStorage,
                scheduleLocalStorage: scheduleLocalStorage,
                environmentStorage: base.userDefaultEnvironmentStorage
            )
        }
    }
}
