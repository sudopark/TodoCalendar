//
//  TodoEventRepositoryFactory.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


// MARK: - TodoEventRepositoryFactory

struct TodoEventRepositoryFactory {

    private let base: AppExtensionBase
    init(base: AppExtensionBase) {
        self.base = base
    }

    func makeRepository() -> any TodoEventRepository {
        let auth = self.base.authStore.loadCurrentAuth()

        if let auth {
            let localStorage = TodoLocalStorageImple(
                sqliteService: base.writableSqliteService
            )

            let remote = base.remoteAPI
            let credential = APICredential(auth: auth)
            remote.setup(credential: credential)
            return TodoRemoteRepositoryImple(
                remote: TodoRemoteImple(remote: base.remoteAPI),
                cacheStorage: localStorage
            )
        } else {
            let localStorage = TodoLocalStorageImple(
                sqliteService: base.commonSqliteService
            )

            return TodoLocalRepositoryImple(
                localStorage: localStorage,
                environmentStorage: base.userDefaultEnvironmentStorage
            )
        }
    }
}
