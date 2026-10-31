//
//  EventSyncUsecase.swift
//  EventDomainInterface
//
//  Created by sudo.park on 7/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - EventSyncUsecase

public protocol EventSyncUsecase: Sendable, AnyObject {
    
    func sync(_ completed: (@Sendable () -> Void)?)
    func cancelSync()
    func forceSync()
    
    var syncStatus: AnyPublisher<EventSyncStatus, Never> { get }
    func loadLatestSyncDataTimestamp() async throws -> TimeInterval?
}

extension EventSyncUsecase {

    public func sync() { self.sync(nil) }

    public var isSyncInProgress: AnyPublisher<Bool, Never> {
        return self.syncStatus
            .map { $0 != .idle }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
