//
//  TemporaryUserDataMigrationUescase.swift
//  MigrationDomainInterface
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - TemporaryUserDataMigrationUescase

public protocol TemporaryUserDataMigrationUescase: Sendable, AnyObject {
    
    func checkIsNeedMigration()
    func startMigration()
    
    var isNeedMigration: AnyPublisher<Bool, Never> { get }
    var migrationNeedEventCount: AnyPublisher<Int, Never> { get }
    var isMigrating: AnyPublisher<Bool, Never> { get }
    var migrationResult: AnyPublisher<Result<Void, any Error>, Never> { get }
}
