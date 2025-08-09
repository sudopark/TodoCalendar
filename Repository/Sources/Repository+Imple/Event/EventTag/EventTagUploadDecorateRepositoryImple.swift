//
//  EventTagUploadDecorateRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions

public final class EventTagUploadDecorateRepositoryImple: EventTagRepository {
    
    private let localRepository: EventTagLocalRepositoryImple
    private let eventUploadService: any EventUploadService
    public init(
        localRepository: EventTagLocalRepositoryImple,
        eventUploadService: any EventUploadService
    ) {
        self.localRepository = localRepository
        self.eventUploadService = eventUploadService
    }
}

extension EventTagUploadDecorateRepositoryImple {
    
    public func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        let newTag = try await self.localRepository.makeNewTag(params)
        try await self.eventUploadService.append(
            .init(dataType: .eventTag, uuid: newTag.uuid, isRemovingTask: false)
        )
        return newTag
    }
    
    public func editTag(
        _ tagId: String, _ params: CustomEventTagEditParams
    ) async throws -> CustomEventTag {
        let updated = try await self.localRepository.editTag(tagId, params)
        try await self.eventUploadService.append(
            .init(dataType: .eventTag, uuid: updated.uuid, isRemovingTask: false)
        )
        return updated
    }
    
    public func deleteTag(_ tagId: String) async throws {
        try await self.localRepository.deleteTag(tagId)
        try await self.eventUploadService.append(
            .init(dataType: .eventTag, uuid: tagId, isRemovingTask: true)
        )
    }
    
    public func deleteTagWithAllEvents(
        _ tagId: String
    ) async throws -> RemoveCustomEventTagWithEventsResult {
        try await self.localRepository.deleteTag(tagId)
        let result = try await self.localRepository.deleteTagWithAllEvents(tagId)
        
        let tasks: [EventUploadingTask] = [
            .init(dataType: .eventTag, uuid: tagId, isRemovingTask: true)
        ]
        + result.todoIds.map { .init(dataType: .todo, uuid: $0, isRemovingTask: true) }
        + result.scheduleIds.map { .init(dataType: .schedule, uuid: $0, isRemovingTask: true) }
        try await self.eventUploadService.append(tasks)
        
        return result
    }
}

extension EventTagUploadDecorateRepositoryImple {
    
    public func loadCustomTags(_ ids: [String]) -> AnyPublisher<[CustomEventTag], any Error> {
        return self.localRepository.loadCustomTags(ids)
    }
    
    public func loadAllCustomTags() -> AnyPublisher<[CustomEventTag], any Error> {
        return self.localRepository.loadAllCustomTags()
    }
    
    public func loadOffTags() -> Set<EventTagId> {
        return self.localRepository.loadOffTags()
    }
    
    public func toggleTagIsOn(_ tagId: EventTagId) -> Set<EventTagId> {
        return self.localRepository.toggleTagIsOn(tagId)
    }
    
    public func resetExternalCalendarOffTagId(_ serviceId: String) {
        self.localRepository.resetExternalCalendarOffTagId(serviceId)
    }
}
