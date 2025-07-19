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
    
    private let remote: any RemoteAPI
    private let cacheStore: any ScheduleEventLocalStorage
    
    public init(
        remote: any RemoteAPI,
        cacheStore: any ScheduleEventLocalStorage
    ) {
        self.remote = remote
        self.cacheStore = cacheStore
    }
}


extension ScheduleEventRemoteRepositoryImple {
    
    public func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        let endpoint = ScheduleEventEndpoints.make
        let payload = params.asJson()
        let mapper: ScheduleEventMapper = try await self.remote.request(
            .post,
            endpoint,
            parameters: payload
        )
        let event = mapper.event
        try? await self.cacheStore.saveScheduleEvent(event)
        return event
    }
    
    public func updateScheduleEvent(
        _ eventId: String,
        _ params: SchedulePutParams
    ) async throws -> ScheduleEvent {
        let endpoint = ScheduleEventEndpoints.schedule(id: eventId)
        let payload = params.asJson()
        let mapper: ScheduleEventMapper = try await self.remote.request(
            .put,
            endpoint,
            parameters: payload
        )
        let updated = mapper.event
        try? await self.cacheStore.updateScheduleEvent(updated)
        return updated
    }
    
    public func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime,
        asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult {
        let payload = ExcludeScheduleEventTimeParams(params, currentTime).asJson()
        let endpoint = ScheduleEventEndpoints.exclude(id: originEventId)
        let mapper: ExcludeRepeatingEventResultMapper = try await self.remote.request(
            .post,
            endpoint,
            parameters: payload
        )
        let result = mapper.result
        
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
        let payload = BranchNewRepeatingScheduleFromOriginParams(
            fromTime, params.asMakeParams()
        ).asJson()
        let endpoint = ScheduleEventEndpoints.branchRepeating(id: originEventId)
        let mapper: BranchNewRepeatingScheduleFromOriginResultMapper = try await self.remote.request(
            .post,
            endpoint,
            parameters: payload
        )
        
        let result = mapper.result
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
        let endpoint = ScheduleEventEndpoints.exclude(id: eventId)
        let payload: [String: Any] = [
            "exclude_repeatings": time.customKey
        ]
        let mapper: ScheduleEventMapper = try await remote.request(
            .patch,
            endpoint,
            parameters: payload
        )
        let updated = mapper.event
        try? await self.cacheStore.updateScheduleEvent(updated)
        return RemoveSheduleEventResult()
            |> \.nextRepeatingEvnet .~ updated
            |> \.syncTimestamp .~ updated.syncTimestamp
    }
    
    private func removeScheduleEvent(
        _ eventId: String
    ) async throws -> RemoveSheduleEventResult {
        let endpoint = ScheduleEventEndpoints.schedule(id: eventId)
        let mapper: RemoveSheduleEventResultMapper = try await self.remote.request(
            .delete, endpoint
        )
        try? await self.cacheStore.removeScheduleEvent(eventId)
        return RemoveSheduleEventResult()
            |> \.syncTimestamp .~ mapper.syncTimestamp
    }
}

extension ScheduleEventRemoteRepositoryImple {
    
    public func loadScheduleEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[ScheduleEvent], any Error> {
        
        return self.loadScheduleEventWithReplaceCache { [weak self] in
            return try await self?.cacheStore.loadScheduleEvents(in: range)
        } thenFromRemote: { [weak self] in
            let payload: [String: Any] = ["lower": range.lowerBound, "upper": range.upperBound]
            let mappers: [ScheduleEventMapper]? = try await self?.remote.request(
                .get,
                ScheduleEventEndpoints.schedules,
                parameters: payload
            )
            return mappers?.map { $0.event }
        }
    }
    
    public func scheduleEvent(
        _ eventId: String
    ) -> AnyPublisher<ScheduleEvent, any Error> {
    
        return self.loadScheduleEventWithReplaceCache { [weak self] in
            let cache = try await self?.cacheStore.loadScheduleEvent(eventId)
            return cache.map { [$0] }
        } thenFromRemote: { [weak self] in
            let refreshed = try await self?.loadEvent(eventId)
            return refreshed.map { [$0] }
        }
        .compactMap { $0.first }
        .eraseToAnyPublisher()
    }
    
    private func loadEvent(_ eventId: String) async throws -> ScheduleEvent {
        let endpoint = ScheduleEventEndpoints.schedule(id: eventId)
        let mapper: ScheduleEventMapper = try await self.remote.request(
            .get, endpoint
        )
        return mapper.event
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
