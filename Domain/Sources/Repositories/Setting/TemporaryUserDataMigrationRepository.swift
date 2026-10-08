//
//  TemporaryUserDataMigrationRepository.swift
//  Domain
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public protocol TemporaryUserDataMigrationRepository {
    
    func loadMigrationNeedEventCount() async throws -> Int
    func migrateEventTags() async throws
    func migrateTodoEvents() async throws
    func migrateScheduleEvents() async throws
    func migrateEventDetails() async throws
    func migrateDoneEvents() async throws
    func migrateCustomColorThemes() async throws
    func clearTemporaryUserData() async throws
}
