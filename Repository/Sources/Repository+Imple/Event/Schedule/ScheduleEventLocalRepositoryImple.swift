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
    
    private let localStorage: any ScheduleEventLocalStorage
    private let environmentStorage: any EnvironmentStorage
    public init(
        localStorage: any ScheduleEventLocalStorage,
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
        return newEvent
    }
    
    public func updateScheduleEvent(
        _ eventId: String,
        _ params: SchedulePutParams
    ) async throws -> ScheduleEvent {
        let origin = try await self.localStorage.loadScheduleEvent(eventId)
        let updated = origin.applyUpdate(params)
        try await self.localStorage.updateScheduleEvent(updated)
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
        return .init(newEvent: newEvent, originEvent: updated)
    }
    
    public func branchNewRepeatingEvent(
        _ originEventId: String, 
        fromTime: TimeInterval,
        _ params: SchedulePutParams
    ) async throws -> BranchNewRepeatingScheduleFromOriginResult {
        let endOriginEvent = try await self.endRepeatingEvent(originEventId, endTime: fromTime)
        let makeParams = params.asMakeParams()
        let newEvent = try await self.makeScheduleEvent(makeParams)
        return .init(reppatingEndOriginEvent: endOriginEvent, newRepeatingEvent: newEvent)
    }
    
    private func endRepeatingEvent(_ originEventId: String, endTime: TimeInterval) async throws -> ScheduleEvent {
        let origin = try await self.localStorage.loadScheduleEvent(originEventId)
        guard let repeating = origin.repeating else { return origin }
        
        let newRepeating = repeating |> \.repeatingEndOption .~ .until(endTime)
        let updatedOrigin = origin |> \.repeating .~ newRepeating
        try await self.localStorage.updateScheduleEvent(updatedOrigin)
        return updatedOrigin
    }
    
    public func removeEvent(
        _ eventId: String, onlyThisTime: EventTime?
    ) async throws -> RemoveSheduleEventResult {
        
        let origin = try await self.localStorage.loadScheduleEvent(eventId)
        try await self.localStorage.removeScheduleEvent(eventId)
        
        guard let onlyThisTime else {
            return RemoveSheduleEventResult()
        }
        
        let updated = origin |> \.repeatingTimeToExcludes <>~ [onlyThisTime.customKey]
        try await self.localStorage.updateScheduleEvent(updated)
        return RemoveSheduleEventResult() |> \.nextRepeatingEvnet .~ updated
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
    
    public func scheduleEvent(_ eventId: String) -> AnyPublisher<ScheduleEvent, any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadScheduleEvent(eventId)
        }
        .eraseToAnyPublisher()
    }
}

private extension ScheduleEvent {
    
    func applyUpdate(_ params: SchedulePutParams) -> ScheduleEvent {
        let excludeTimes: Set<String> = params.repeatingTimeToExcludes.map { Set($0) } ?? []
        return self
            |> \.name .~ (params.name ?? self.name)
            |> \.time .~ (params.time ?? self.time)
            |> \.eventTagId .~ params.eventTagId
            |> \.repeating .~ params.repeating
            |> \.showTurn .~ (params.showTurn ?? false)
            |> \.notificationOptions .~ (params.notificationOptions ?? [])
            |> \.repeatingTimeToExcludes .~ excludeTimes
    }
}
