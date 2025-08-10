//
//  EventSyncUsecase.swift
//  Domain
//
//  Created by sudo.park on 7/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - EventSyncUsecase

public protocol EventSyncUsecase: Sendable {
    
    func sync(_ dataType: SyncDataType)
    
    var isSyncInProgress: AnyPublisher<Bool, Never> { get }
}



// MARK: - EventSyncUsecaseImple

public final class EventSyncUsecaseImple: EventSyncUsecase, @unchecked Sendable {
    
    private let syncRepository: any EventSyncRepository
    private let eventSyncMediator: any EventSyncMediator
    
    public init(
        syncRepository: any EventSyncRepository,
        eventSyncMediator: any EventSyncMediator
    ) {
        self.syncRepository = syncRepository
        self.eventSyncMediator = eventSyncMediator
    }
    
    private enum Constant {
        static let pageSize: Int = 30
    }
    private struct Subject {
        let isSyncing = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()
    private var syncTaskMap: [SyncDataType: Task<Void, any Error>] = [:]
}


extension EventSyncUsecaseImple {
    
    public func sync(_ dataType: SyncDataType) {
        
        self.syncTaskMap[dataType]?.cancel()
        self.syncTaskMap[dataType] = nil
        
        let task = Task { [weak self] in
            
            try await self?.eventSyncMediator.waitUntilEventSyncAvailable()
            
            self?.subject.isSyncing.send(true)
            logger.log(level: .debug, "\(dataType) sync start")
            do {
                try await self?.runSync(dataType)
                logger.log(level: .debug, "\(dataType) sync end")
            } catch let error {
                logger.log(level: .error, "\(dataType) sync fail: \(error)")
            }
            self?.subject.isSyncing.send(false)
        }
        self.syncTaskMap[dataType] = task
    }
    
    private func runSync(_ dataType: SyncDataType) async throws {
        let checkIsNeed = try await self.syncRepository.checkIsNeedSync(for: dataType)
        switch (checkIsNeed.result, dataType) {
        case (.noNeedToSync, _):
            logger.log(level: .debug, "\(dataType) no need to sync")
        case (.migrationNeeds, .eventTag):
            try await self.startSync(CustomEventTag.self, dataType)
            
        case (.migrationNeeds, .todo):
            try await self.startSync(TodoEvent.self, dataType)
            
        case (.migrationNeeds, .schedule):
            try await self.startSync(ScheduleEvent.self, dataType)
        
        case (.needToSync, .eventTag):
            try await self.startSync(CustomEventTag.self, dataType, from: checkIsNeed.startTimestamp)
            
        case (.needToSync, .todo):
            try await self.startSync(TodoEvent.self, dataType, from: checkIsNeed.startTimestamp)
            
        case (.needToSync, .schedule):
            try await self.startSync(ScheduleEvent.self, dataType, from: checkIsNeed.startTimestamp)
        }
    }
    
    private func startSync<T: Sendable>(
        _ responseType: T.Type,
        _ dataType: SyncDataType,
        from startTimestamp: Int? = nil
    ) async throws {
    
        try await self.eventSyncMediator.waitUntilEventSyncAvailable()
        
        let firstPage: EventSyncResponse<T> = try await self.syncRepository.startSync(
            for: dataType, startFrom: startTimestamp, pageSize: Constant.pageSize
        )
        
        var nextPageCursor = firstPage.nextPageCursor
        
        while let cursor = nextPageCursor {
            
            try await self.eventSyncMediator.waitUntilEventSyncAvailable()
            
            let nextPage: EventSyncResponse<T> = try await self.syncRepository.continueSync(
                for: dataType, cursor: cursor, pageSize: Constant.pageSize
            )
            nextPageCursor = nextPage.nextPageCursor
        }
    }
}

extension EventSyncUsecaseImple {
    
    public var isSyncInProgress: AnyPublisher<Bool, Never> {
        return self.subject.isSyncing
            .eraseToAnyPublisher()
    }
}
