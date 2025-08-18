//
//  ScheduleEventRemoteRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 3/28/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions


public final class ScheduleEventRemoteRepositoryImple: ScheduleEventRepository, Sendable {
    
    private let remote: any ScheduleEventRemote
    private let cacheStore: any ScheduleEventLocalStorage
    
    public init(
        remote: any ScheduleEventRemote,
        cacheStore: any ScheduleEventLocalStorage
    ) {
        self.remote = remote
        self.cacheStore = cacheStore
    }
}


extension ScheduleEventRemoteRepositoryImple {
    
    public func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        
        let event = try await remote.makeScheduleEvent(params)
        try? await self.cacheStore.saveScheduleEvent(event)
        return event
    }
    
    public func updateScheduleEvent(
        _ eventId: String,
        _ params: SchedulePutParams
    ) async throws -> ScheduleEvent {
        
        let updated = try await self.remote.updateScheduleEvent(eventId, params)
        try? await self.cacheStore.updateScheduleEvent(updated)
        return updated
    }
    
    public func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime,
        asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult {
        
        let result = try await self.remote.excludeRepeatingEvent(originEventId, at: currentTime, asNew: params)
        
        // updateCache
        try? await cacheStore.updateScheduleEvent(result.originEvent)
        try? await cacheStore.saveScheduleEvent(result.newEvent)
        return result
    }
    
    public func branchNewRepeatingEvent(
        _ originEventId: String,
        fromTime: TimeInterval,
        _ params: SchedulePutParams
    ) async throws -> BranchNewRepeatingScheduleFromOriginResult {
        
        let result = try await self.remote.branchNewRepeatingEvent(originEventId, fromTime: fromTime, params)
        try? await cacheStore.updateScheduleEvent(result.reppatingEndOriginEvent)
        try? await cacheStore.saveScheduleEvent(result.newRepeatingEvent)
        return result
    }
    
    public func removeEvent(
        _ eventId: String,
        onlyThisTime: EventTime?
    ) async throws -> RemoveSheduleEventResult {
        if let time = onlyThisTime {
            return try await self.removeRepeatingScheduleEventTime(eventId, time)
        } else {
            return try await self.removeScheduleEvent(eventId)
        }
    }
    
    private func removeRepeatingScheduleEventTime(
        _ eventId: String, _ time: EventTime
    ) async throws -> RemoveSheduleEventResult {
        
        let updated = try await self.remote.removeRepeatingScheduleEventTime(eventId, time)
        try? await self.cacheStore.updateScheduleEvent(updated)
        return RemoveSheduleEventResult() |> \.nextRepeatingEvnet .~ updated
    }
    
    private func removeScheduleEvent(
        _ eventId: String
    ) async throws -> RemoveSheduleEventResult {
        
        try await self.remote.removeScheduleEvent(eventId)
        try? await self.cacheStore.removeScheduleEvent(eventId)
        return .init()
    }
}

extension ScheduleEventRemoteRepositoryImple {
    
    public func loadScheduleEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[ScheduleEvent], any Error> {
        
        return self.loadScheduleEventWithReplaceCache { [weak self] in
            return try await self?.cacheStore.loadScheduleEvents(in: range)
        } thenFromRemote: { [weak self] in
            return try await self?.remote.loadScheduleEvents(in: range)
        }
    }
    
    public func scheduleEvent(
        _ eventId: String
    ) -> AnyPublisher<ScheduleEvent, any Error> {
    
        return self.loadScheduleEventWithReplaceCache { [weak self] in
            let cache = try await self?.cacheStore.loadScheduleEvent(eventId)
            return cache.map { [$0] }
        } thenFromRemote: { [weak self] in
            let refreshed = try await self?.remote.loadScheduleEvent(eventId)
            return refreshed.map { [$0] }
        }
        .compactMap { $0.first }
        .eraseToAnyPublisher()
    }
    
    private func loadScheduleEventWithReplaceCache(
        startWithCached cacheOperation: @Sendable @escaping () async throws -> [ScheduleEvent]?,
        thenFromRemote remoteOperation: @Sendable @escaping () async throws -> [ScheduleEvent]?
    ) -> AnyPublisher<[ScheduleEvent], any Error> {
        
        return AnyPublisher<[ScheduleEvent]?, any Error>.create { subscriber in
            let task = Task { [weak self] in
                let cached = try? await cacheOperation()
                if let cached {
                    subscriber.send(cached)
                }
                do {
                    let refreshed = try await remoteOperation()
                    await self?.replaceCached(cached, refreshed)
                    subscriber.send(refreshed)
                    subscriber.send(completion: .finished)
                } catch {
                    subscriber.send(completion: .failure(error))
                }
            }
            return AnyCancellable { task.cancel() }
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
    
    private func replaceCached(
        _ cached: [ScheduleEvent]?,
        _ refreshed: [ScheduleEvent]?
    ) async {
        if let cached {
            try? await self.cacheStore.removeScheduleEvents(cached.map { $0.uuid })
        }
        if let refreshed {
            try? await self.cacheStore.updateScheduleEvents(refreshed)
        }
    }
}
