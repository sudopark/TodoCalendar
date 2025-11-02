//
//  EventTagLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions


public final class EventTagLocalRepositoryImple: EventTagRepository {
    
    private let localStorage: any EventTagLocalStorage
    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleLocalStorage: any ScheduleEventLocalStorage
    public init(
        localStorage: any EventTagLocalStorage,
        todoLocalStorage: any TodoLocalStorage,
        scheduleLocalStorage: any ScheduleEventLocalStorage
    ) {
        self.localStorage = localStorage
        self.todoLocalStorage = todoLocalStorage
        self.scheduleLocalStorage = scheduleLocalStorage
    }
}


extension EventTagLocalRepositoryImple {
    
    public func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        let sameNameTags = try await self.localStorage.loadTag(match: params.name)
        guard sameNameTags.isEmpty
        else {
            throw RuntimeError(key: "EvnetTag_Name_Duplicated", "event tag name:\(params.name) is already exists")
        }
        let tag = CustomEventTag(uuid: UUID().uuidString, name: params.name, colorHex: params.colorHex)
        try await self.localStorage.saveTag(tag)
        return tag
    }
    
    public func editTag(
        _ tagId: String,
        _ params: CustomEventTagEditParams
    ) async throws -> CustomEventTag {
        let sameNameOtherTags = try await self.localStorage.loadTag(match: params.name).filter { $0.uuid != tagId }
        guard sameNameOtherTags.isEmpty
        else {
            throw RuntimeError(key: "EvnetTag_Name_Duplicated", "event tag name:\(params.name) is already exists")
        }
        try await self.localStorage.editTag(tagId, with: params)
        return try await self.localStorage.loadTags(in: [tagId]).first.unwrap()
    }
    
    public func deleteTag(_ tagId: String) async throws {
        try await self.localStorage.deleteTag(tagId)
        self.localStorage.deleteOfftagId(tagId)
    }
    
    public func deleteTagWithAllEvents(_ tagId: String) async throws -> RemoveCustomEventTagWithEventsResult {
        
        try await self.deleteTag(tagId)
        let todoIds = try await self.todoLocalStorage.removeTodosWith(tagId: tagId)
        let scheduleIds = try await self.scheduleLocalStorage.removeSchedulesWith(tagId: tagId)
        return .init(todoIds: todoIds, scheduleIds: scheduleIds)
    }
}

extension EventTagLocalRepositoryImple {
    
    public func loadCustomTags(_ ids: [String]) -> AnyPublisher<[CustomEventTag], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadTags(in: ids)
        }
        .eraseToAnyPublisher()
    }
    
    public func loadAllCustomTags() -> AnyPublisher<[CustomEventTag], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadAllTags()
        }
        .eraseToAnyPublisher()
    }
    
    public func loadOffTags() -> Set<EventTagId> {
        return self.localStorage.loadOffTags()
    }
    
    public func toggleTagIsOn(_ tagId: EventTagId) -> Set<EventTagId> {
        return self.localStorage.toggleTagIsOn(tagId)
    }
    
    public func addOffIds(_ ids: [EventTagId]) -> Set<EventTagId> {
        return self.localStorage.addOffIds(ids)
    }
    
    public func resetExternalCalendarOffTagId(_ serviceId: String) {
        self.localStorage.resetExternalCalendarOffTagId(serviceId)
    }
}
