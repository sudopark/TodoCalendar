//
//  ScheduleEventUploadDecorateRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


public final class ScheduleEventUploadDecorateRepositoryImple: ScheduleEventRepository {
    
    private let localRepository: ScheduleEventLocalRepositoryImple
    private let eventUploadService: any EventUploadService
    
    public init(
        localRepository: ScheduleEventLocalRepositoryImple,
        eventUploadService: any EventUploadService
    ) {
        self.localRepository = localRepository
        self.eventUploadService = eventUploadService
    }
}

extension ScheduleEventUploadDecorateRepositoryImple {
    
    public func makeScheduleEvent(
        _ params: ScheduleMakeParams
    ) async throws -> ScheduleEvent {
        let newEvent = try await self.localRepository.makeScheduleEvent(params)
        try await self.eventUploadService.append(
            .init(dataType: .schedule, uuid: newEvent.uuid, isRemovingTask: false)
        )
        return newEvent
    }
    
    public func updateScheduleEvent(
        _ eventId: String, _ params: SchedulePutParams
    ) async throws -> ScheduleEvent {
        let updated = try await self.localRepository.updateScheduleEvent(eventId, params)
        try await self.eventUploadService.append(
            .init(dataType: .schedule, uuid: updated.uuid, isRemovingTask: false)
        )
        return updated
    }
    
    public func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime, asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult {
        let result = try await self.localRepository.excludeRepeatingEvent(
            originEventId, at: currentTime, asNew: params
        )
        try await self.eventUploadService.append([
            .init(dataType: .schedule, uuid: result.originEvent.uuid, isRemovingTask: false),
            .init(dataType: .schedule, uuid: result.newEvent.uuid, isRemovingTask: false)
        ])
        return result
    }
    
    public func branchNewRepeatingEvent(
        _ originEventId: String,
        fromTime: TimeInterval, _ params: SchedulePutParams
    ) async throws -> BranchNewRepeatingScheduleFromOriginResult {
        let result = try await self.localRepository.branchNewRepeatingEvent(
            originEventId, fromTime: fromTime, params
        )
        try await self.eventUploadService.append([
            .init(dataType: .schedule, uuid: result.reppatingEndOriginEvent.uuid, isRemovingTask: false),
            .init(dataType: .schedule, uuid: result.newRepeatingEvent.uuid, isRemovingTask: false)
        ])
        return result
    }
    
    public func removeEvent(
        _ eventId: String, onlyThisTime: EventTime?
    ) async throws -> RemoveSheduleEventResult {
        let result = try await self.localRepository.removeEvent(
            eventId, onlyThisTime: onlyThisTime
        )
        if let next = result.nextRepeatingEvnet {
            try await self.eventUploadService.append(
                .init(dataType: .schedule, uuid: next.uuid, isRemovingTask: false)
            )
        } else {
            try await self.eventUploadService.append([
                .init(dataType: .schedule, uuid: eventId, isRemovingTask: true),
                .init(dataType: .eventDetail, uuid: eventId, isRemovingTask: true)
            ])
        }
        return result
    }
}

extension ScheduleEventUploadDecorateRepositoryImple {
    
    public func loadScheduleEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[ScheduleEvent], any Error> {
        return self.localRepository.loadScheduleEvents(in: range)
    }
    
    public func scheduleEvent(
        _ eventId: String
    ) -> AnyPublisher<ScheduleEvent, any Error> {
        return self.localRepository.scheduleEvent(eventId)
    }
}
