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
        let syncStatus = CurrentValueSubject<EventSyncStatus, Never>(.idle)
    }
    private let subject = Subject()
    private var syncTask: Task<Void, any Error>?
}


extension EventSyncUsecaseImple {
    
    public func sync(_ completed: (@Sendable () -> Void)?) {
        
        self.cancelSync()
        
        let task = Task { [weak self] in
            try await self?.runSyncTask()
            completed?()
        }
        self.syncTask = task
    }
    
    public func cancelSync() {
        self.syncTask?.cancel()
        self.syncTask = nil
        self.subject.syncStatus.send(.idle)
    }
    
    public func forceSync() {
        
        self.cancelSync()
        
        let task = Task { [weak self] in
            try await self?.syncRepository.clearSyncTimestamp()
            try await self?.runSyncTask()
        }
        self.syncTask = task
    }
    
    private func runSyncTask() async throws {
        self.subject.syncStatus.send(.incrementalSyncing)

        try await self.eventSyncMediator.waitUntilEventSyncAvailable()

        logger.log(level: .debug, "event sync process start")

        let dataTypes: [SyncDataType] = [.eventTag, .todo, .schedule]
        await dataTypes.asyncForEach { dataType in
            do {
                try await self.runSync(dataType)
            } catch let error {
                logger.log(level: .error, "\(dataType) sync fail: \(error)")
            }
        }

        logger.log(level: .debug, "event sync process end")
        self.subject.syncStatus.send(.idle)
    }

    private func runSync(_ dataType: SyncDataType) async throws {
        let checkIsNeed = try await self.syncRepository.checkIsNeedSync(for: dataType)
        if checkIsNeed.result == .migrationNeeds {
            self.subject.syncStatus.send(.fullSyncing)
        }
        switch (checkIsNeed.result, dataType) {
        case (.noNeedToSync, _): break
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
    
    public var syncStatus: AnyPublisher<EventSyncStatus, Never> {
        return self.subject.syncStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func loadLatestSyncDataTimestamp() async throws -> TimeInterval? {
        return try await self.syncRepository.loadLatestSyncDataTimestamp()
    }
}


// MARK: - NotNeedEventSyncUsecase

public final class NotNeedEventSyncUsecase: EventSyncUsecase, Sendable {
    
    public init() { }
    
    public func sync(_ completed: (() -> Void)?) {
        completed?()
    }
    
    public func cancelSync() { }
    
    public func forceSync() { }
    
    public var syncStatus: AnyPublisher<EventSyncStatus, Never> {
        return Just(.idle).eraseToAnyPublisher()
    }
    
    public func loadLatestSyncDataTimestamp() async throws -> TimeInterval? {
        return nil
    }
}
