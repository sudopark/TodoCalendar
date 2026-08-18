//
//  StubEventSyncUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 8/11/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


open class StubEventSyncUsecase: EventSyncUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var didSyncRequested: Bool = false
    public var didSyncRequestedCount: Int = 0
    private let isSyncSubject = CurrentValueSubject<EventSyncStatus, Never>(.idle)
    public var stubStatusWhileSyncing: EventSyncStatus = .incrementalSyncing

    open func sync(_ completed: (@Sendable () -> Void)?) {
        self.isSyncSubject.send(self.stubStatusWhileSyncing)
        self.didSyncRequested = true
        self.didSyncRequestedCount += 1
        self.isSyncSubject.send(.idle)
        completed?()
    }

    open func forceSync() {
        self.sync(nil)
    }

    open func cancelSync() {
        self.isSyncSubject.send(.idle)
    }

    open var syncStatus: AnyPublisher<EventSyncStatus, Never> {
        return self.isSyncSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    public var lastSyncTime: TimeInterval = 0
    open func loadLatestSyncDataTimestamp() async throws -> TimeInterval? {
        self.lastSyncTime += 3600_000
        return self.lastSyncTime
    }
}
