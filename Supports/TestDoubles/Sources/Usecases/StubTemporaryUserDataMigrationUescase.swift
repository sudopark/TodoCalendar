//
//  StubTemporaryUserDataMigrationUescase.swift
//  TestDoubles
//
//  Created by sudo.park on 4/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


open class StubTemporaryUserDataMigrationUescase: TemporaryUserDataMigrationUescase, @unchecked Sendable {
    
    public init() { }

    private enum Status {
        case migrating
        case success
        case failed(any Error)
    }
    private let migrationTargetEventCount = CurrentValueSubject<Int, Never>(0)
    private let status = CurrentValueSubject<Status?, Never>(nil)

    open func checkIsNeedMigration() {
        self.migrationTargetEventCount.send(100)
    }
    
    public var shouldFail: Bool = false
    open func startMigration() {
        self.status.send(.migrating)
        if shouldFail {
            self.status.send(.failed(RuntimeError("failed")))
            self.migrationTargetEventCount.send(10)
        } else {
            self.status.send(.success)
            self.migrationTargetEventCount.send(0)
        }
    }
    
    open var isNeedMigration: AnyPublisher<Bool, Never> {
        return self.migrationTargetEventCount
            .map { $0 > 0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    open var migrationNeedEventCount: AnyPublisher<Int, Never> {
        return self.migrationTargetEventCount
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    open var isMigrating: AnyPublisher<Bool, Never> {
        let transform: (Status?) -> Bool = {
            guard case .migrating = $0 else { return false }
            return true
        }
        return self.status
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    open var migrationResult: AnyPublisher<Result<Void, any Error>, Never> {
        let transform: (Status?) -> Result<Void, any Error>? = {
            switch $0 {
            case .success: return .success(())
            case .failed(let error): return .failure(error)
            default: return nil
            }
        }
        return self.status
            .compactMap(transform)
            .eraseToAnyPublisher()
    }
}
