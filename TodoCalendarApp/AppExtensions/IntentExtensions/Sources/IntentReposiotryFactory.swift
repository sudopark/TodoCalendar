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

        return EventTagLocalRepositoryImple(
            localStorage: EventTagLocalStorageImple(
                sqliteService: base.commonSqliteService
            ),
            environmentStorage: base.userDefaultEnvironmentStorage
        )
    }
}
