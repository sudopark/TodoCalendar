//
//  EventSyncMediator.swift
//  Domain
//
//  Created by sudo.park on 8/10/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

public protocol EventSyncMediator: Sendable {
    
    func waitUntilEventSyncAvailable() async throws
}


public final class EventSyncMediatorImple: EventSyncMediator, @unchecked Sendable {
    
    private let waitCheckInterval: Duration
    private let eventUploadService: any EventUploadService
    private let migrationUsecase: any TemporaryUserDataMigrationUescase
    
    public init(
        waitCheckInterval: Duration = .seconds(1),
        eventUploadService: any EventUploadService,
        migrationUsecase: any TemporaryUserDataMigrationUescase
    ) {
        self.waitCheckInterval = waitCheckInterval
        self.eventUploadService = eventUploadService
        self.migrationUsecase = migrationUsecase
        
        self.internalBinding()
    }
    
    private struct Subject {
        let isTemporaryUserDataMigration = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
    
    private func internalBinding() {
        
        self.migrationUsecase.isMigrating
            .sink(receiveValue: { [weak self] isMigrating in
                self?.subject.isTemporaryUserDataMigration.send(isMigrating)
            })
            .store(in: &self.cancellables)
    }
}

extension EventSyncMediatorImple {
    
    public func waitUntilEventSyncAvailable() async throws {
        try await self.eventUploadService.waitUntilUploadingEnd(self.waitCheckInterval)
        
        while self.subject.isTemporaryUserDataMigration.value {
            try await Task.sleep(for: self.waitCheckInterval)
        }
    }
}
