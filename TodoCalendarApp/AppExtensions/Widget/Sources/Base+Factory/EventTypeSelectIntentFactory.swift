//
//  EventTypeSelectIntentFactory.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import Repository


struct EventTypeSelectIntentFactory {
    
    private let base: AppExtensionBase
    init(base: AppExtensionBase) {
        self.base = base
    }
}

extension EventTypeSelectIntentFactory {
    
    func makeEventTagRepository() -> any EventTagRepository {
        
        let auth = self.base.authStore.loadCurrentAuth()
        let localStorage = EventTagLocalStorageImple(
            sqliteService: base.commonSqliteService,
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let todoLocalStorage = TodoLocalStorageImple(sqliteService: base.commonSqliteService)
        let scheduleLocalStorage = ScheduleEventLocalStorageImple(sqliteService: base.commonSqliteService)
        
        let eventDetailLocalStorage = EventDetailDataLocalStorageImple<EventDetailDataTable>(sqliteService: base.commonSqliteService)
        
        if let auth {
            let remote = base.remoteAPI
            let credential = APICredential(auth: auth)
            remote.setup(credential: credential)
            return EventTagRemoteRepositoryImple(
                remote: EventTagRemoteImple(remote: remote),
                cacheStorage: localStorage,
                todoCacheStorage: todoLocalStorage,
                scheduleCacheStorage: scheduleLocalStorage,
                eventDetailCacheStorage: eventDetailLocalStorage
            )
        } else {
            return EventTagLocalRepositoryImple(
                localStorage: localStorage,
                todoLocalStorage: todoLocalStorage,
                scheduleLocalStorage: scheduleLocalStorage,
                eventDetailLocalStorage: eventDetailLocalStorage
            )
        }
    }
    
    func makeExternalCalendarAcountRepository() -> any ExternalCalendarIntegrateRepository {
        
        return ExternalCalendarIntegrateRepositoryImple(
            supportServices: AppEnvironment.supportExternalCalendarServices,
            remotePool: NopExternalCalendarAccountRemotePool(),
            keyChainStore: self.base.keyChainStorage,
            appleCalendarPermissionChecker: self.base.appleCalendarPermissionChecker
        )
    }
    
    func makeGoogleCalendarRepository() -> any GoogleCalendarRepository {
        return GoogleCalendarLocalAggregatedRepositoryImple(
            connectionPool: base.externalCalendarDBConnectionPool,
            accountRepository: makeExternalCalendarAcountRepository()
        )
    }

    func makeAppleCalendarRepository() -> any AppleCalendarRepository {
        return AppleCalendarLocalAggregatedRepositoryImple(
            connectionPool: base.externalCalendarDBConnectionPool
        )
    }
}
