//
//  ScheduleEventRemote.swift
//  Repository
//
//  Created by sudo.park on 7/25/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - ScheduleEventRemote

public protocol ScheduleEventRemote: Sendable {
    
    func makeScheduleEvent(
        _ params: ScheduleMakeParams
    ) async throws -> ScheduleEvent
    
    func updateScheduleEvent(
        _ eventId: String,
        _ params: SchedulePutParams
    ) async throws -> ScheduleEvent
    
    func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime,
        asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult
    
    func branchNewRepeatingEvent(
        _ originEventId: String,
        fromTime: TimeInterval,
        _ params: SchedulePutParams
    ) async throws -> BranchNewRepeatingScheduleFromOriginResult
    
    func removeRepeatingScheduleEventTime(
        _ eventId: String, _ time: EventTime
    ) async throws -> ScheduleEvent
    
    func removeScheduleEvent(
        _ eventId: String
    ) async throws
    
    func loadScheduleEvents(in range: Range<TimeInterval>) async throws -> [ScheduleEvent]
    
    func loadScheduleEvent(_ eventId: String) async throws -> ScheduleEvent
}


// MARK: - ScheduleEventRemoteImple

public final class ScheduleEventRemoteImple: ScheduleEventRemote {
    
    private let remote: any RemoteAPI
    public init(remote: any RemoteAPI) {
        self.remote = remote
    }
}

extension ScheduleEventRemoteImple {
    
    public func makeScheduleEvent(
        _ params: ScheduleMakeParams
    ) async throws -> ScheduleEvent {
        
        let endpoint = ScheduleEventEndpoints.make
        let payload = params.asJson()
        let mapper: ScheduleEventMapper = try await self.remote.request(
            .post,
            endpoint,
            parameters: payload
        )
        return mapper.event
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
        return mapper.event
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
        return mapper.result
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
        return mapper.result
    }
    
    public func removeRepeatingScheduleEventTime(
        _ eventId: String, _ time: EventTime
    ) async throws -> ScheduleEvent {
        
        let endpoint = ScheduleEventEndpoints.exclude(id: eventId)
        let payload: [String: Any] = [
            "exclude_repeatings": time.customKey
        ]
        let mapper: ScheduleEventMapper = try await remote.request(
            .patch,
            endpoint,
            parameters: payload
        )
        return mapper.event
    }
    
    public func removeScheduleEvent(
        _ eventId: String
    ) async throws  {
        let endpoint = ScheduleEventEndpoints.schedule(id: eventId)
        let _: RemoveSheduleEventResultMapper = try await self.remote.request(
            .delete, endpoint
        )
    }
    
    public func loadScheduleEvents(in range: Range<TimeInterval>) async throws -> [ScheduleEvent] {
        
        let payload: [String: Any] = ["lower": range.lowerBound, "upper": range.upperBound]
        let mappers: [ScheduleEventMapper] = try await self.remote.request(
            .get,
            ScheduleEventEndpoints.schedules,
            parameters: payload
        )
        return mappers.map { $0.event }
    }
    
    public func loadScheduleEvent(_ eventId: String) async throws -> ScheduleEvent {
        
        let endpoint = ScheduleEventEndpoints.schedule(id: eventId)
        let mapper: ScheduleEventMapper = try await self.remote.request(
            .get, endpoint
        )
        return mapper.event
    }
}
