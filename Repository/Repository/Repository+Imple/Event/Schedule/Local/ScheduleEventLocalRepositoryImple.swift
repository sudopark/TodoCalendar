//
//  ScheduleEventLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions


public final class ScheduleEventLocalRepositoryImple: ScheduleEventRepository, Sendable {
    
    private let localStorage: ScheduleEventLocalStorage
    private let environmentStorage: any EnvironmentStorage
    public init(
        localStorage: ScheduleEventLocalStorage,
        environmentStorage: any EnvironmentStorage
    ) {
        self.localStorage = localStorage
        self.environmentStorage = environmentStorage
    }
}

extension ScheduleEventLocalRepositoryImple {
    
    public func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        guard let newEvent = ScheduleEvent(params)
        else {
            throw RuntimeError("invalid parameter")
        }
        try await localStorage.saveScheduleEvent(newEvent)
        self.updateLatestUsedEventTag(params.eventTagId?.customTagId)
        return newEvent
    }
    
    public func updateScheduleEvent(
        _ eventId: String,
        _ params: ScheduleEditParams
    ) async throws -> ScheduleEvent {
        let origin = try await self.localStorage.loadScheduleEvent(eventId)
        let updated = origin.apply(params)
        try await self.localStorage.updateScheduleEvent(updated)
        self.updateLatestUsedEventTag(params.eventTagId?.customTagId)
        return updated
    }
    
    public func excludeRepeatingEvent(
        _ originEventId: String,
        at currentTime: EventTime,
        asNew params: ScheduleMakeParams
    ) async throws -> ExcludeRepeatingEventResult {
        let newEvent = try await self.makeScheduleEvent(params)
        let origin = try await self.localStorage.loadScheduleEvent(originEventId)
        let updated = origin
            |> \.repeatingTimeToExcludes <>~ [currentTime.customKey]
        try await self.localStorage.updateScheduleEvent(updated)
        self.updateLatestUsedEventTag(params.eventTagId?.customTagId)
        return .init(newEvent: newEvent, originEvent: updated)
    }
    
    private func updateLatestUsedEventTag(_ tagId: String?) {
        let key = "latest_used_event_tag_id"
        if let id = tagId {
            self.environmentStorage.update(key, id)
        } else {
            self.environmentStorage.remove(key)
        }
    }
}

extension ScheduleEventLocalRepositoryImple {
    
    public func loadScheduleEvents(
        in range: Range<TimeInterval>
    ) -> AnyPublisher<[ScheduleEvent], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadScheduleEvents(in: range)
        }
        .eraseToAnyPublisher()
    }
}
