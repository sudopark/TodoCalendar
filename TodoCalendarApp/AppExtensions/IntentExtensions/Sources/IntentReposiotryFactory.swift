//
//  IntentReposiotryFactory.swift
//  TodoCalendarAppIntentExtensions
//
//  Created by sudo.park on 7/27/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
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
        
        let sqliteService = auth == nil ? base.commonSqliteService : base.writableSqliteService
        
        let localStorage = EventTagLocalStorageImple(
            sqliteService: sqliteService,
            environmentStorage: base.userDefaultEnvironmentStorage
        )
        let todoLocalStorage = TodoLocalStorageImple(sqliteService: sqliteService)
        let scheduleLocalStorage = ScheduleEventLocalStorageImple(sqliteService: sqliteService)
        
        if let auth {
            let remote = base.remoteAPI
            let credential = APICredential(auth: auth)
            remote.setup(credential: credential)
            return EventTagRemoteRepositoryImple(
                remote: EventTagRemoteImple(remote: remote),
                cacheStorage: localStorage,
                todoCacheStorage: todoLocalStorage,
                scheduleCacheStorage: scheduleLocalStorage
            )
        } else {
            return EventTagLocalRepositoryImple(
                localStorage: localStorage,
                todoLocalStorage: todoLocalStorage,
                scheduleLocalStorage: scheduleLocalStorage
            )
        }
    }
    
    func makeExternalCalendarAcountRepository() -> any ExternalCalendarIntegrateRepository {
        
        return ExternalCalendarIntegrateRepositoryImple(
            supportServices: AppEnvironment.supportExternalCalendarServices,
            removeAPIPerService: [:],
            keyChainStore: self.base.keyChainStorage
        )
    }
    
    func makeGoogleCalendarRepository() -> any GoogleCalendarRepository {
        return GoogleCalendarRepositoryImple(
            remote: EmptyRemote(),
            cacheStorage: GoogleCalendarLocalStorageImple(sqliteService: base.writableSqliteService)
        )
    }
}
