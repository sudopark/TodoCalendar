//
//  EventTagRemoteRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 4/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import CombineExt
import Domain
import Extensions


public final class EventTagRemoteRepositoryImple: EventTagRepository, @unchecked Sendable {
    
    private let remote: any EventTagRemote
    private let cacheStorage: any EventTagLocalStorage
    private let todoCacheStorage: any TodoLocalStorage
    private let scheduleCacheStorage: any ScheduleEventLocalStorage
    
    public init(
        remote: any EventTagRemote,
        cacheStorage: any EventTagLocalStorage,
        todoCacheStorage: any TodoLocalStorage,
        scheduleCacheStorage: any ScheduleEventLocalStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
        self.todoCacheStorage = todoCacheStorage
        self.scheduleCacheStorage = scheduleCacheStorage
    }
}

extension EventTagRemoteRepositoryImple {
    
    public func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        let tag = try await self.remote.makeTag(params)
        try? await self.cacheStorage.saveTag(tag)
        return tag
    }
    
    public func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag {
        let tag = try await self.remote.editTag(tagId, params)
        try? await self.cacheStorage.updateTags([tag])
        return tag
    }
    
    public func deleteTag(_ tagId: String) async throws {
        let result = try await self.remote.deleteTag(tagId)
        try? await self.cacheStorage.deleteTag(tagId)
        self.cacheStorage.deleteOfftagId(tagId)
        return result
    }
    
    public func deleteTagWithAllEvents(
        _ tagId: String
    ) async throws -> RemoveCustomEventTagWithEventsResult {
        let result = try await self.remote.deleteTagWithAllEvents(tagId)
        try? await self.cacheStorage.deleteTag(tagId)
        try? await self.todoCacheStorage.removeTodos(result.todoIds)
        try? await self.scheduleCacheStorage.removeScheduleEvents(result.scheduleIds)
        return result
    }
    
    public func loadAllCustomTags() -> AnyPublisher<[CustomEventTag], any Error> {
        return self.loadTagsAndReplaceCache { [weak self] in
            return try await self?.cacheStorage.loadAllTags()
        } thenFromRemote: { [weak self] in
            return try await self?.remote.loadAllEventTags()
        }
    }
    
    public func loadCustomTags(_ ids: [String]) -> AnyPublisher<[CustomEventTag], any Error> {
        return self.loadTagsAndReplaceCache { [weak self] in
            return try await self?.cacheStorage.loadTags(in: ids)
        } thenFromRemote: { [weak self] in
            return try await self?.remote.loadCustomTags(ids)
        }
    }
    
    private func loadTagsAndReplaceCache(
        startWithCached cacheOperation: @Sendable @escaping () async throws -> [CustomEventTag]?,
        thenFromRemote remoteOperation: @Sendable @escaping () async throws -> [CustomEventTag]?
    ) -> AnyPublisher<[CustomEventTag], any Error> {
        return AnyPublisher<[CustomEventTag]?, any Error>.create { subscriber in
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
        _ cached: [CustomEventTag]?,
        _ refreshed: [CustomEventTag]?
    ) async {
        if let cached {
            try? await self.cacheStorage.deleteTags(cached.map { $0.uuid })
        }
        if let refreshed {
            try? await self.cacheStorage.updateTags(refreshed)
        }
        
        let refreshedIdSet = (refreshed?.map { $0.uuid } ?? []) |> Set.init
        let onlyRemoved = cached?.filter { !refreshedIdSet.contains($0.uuid) }
        onlyRemoved?.forEach {
            self.cacheStorage.deleteOfftagId($0.uuid)
        }
    }
    
    public func loadOffTags() -> Set<EventTagId> {
        return self.cacheStorage.loadOffTags()
    }
    
    public func toggleTagIsOn(_ tagId: EventTagId) -> Set<EventTagId> {
        return self.cacheStorage.toggleTagIsOn(tagId)
    }
    
    public func addOffIds(_ ids: [EventTagId]) -> Set<EventTagId> {
        return self.cacheStorage.addOffIds(ids)
    }
    
    public func resetExternalCalendarOffTagId(_ serviceId: String) {
        self.cacheStorage.resetExternalCalendarOffTagId(serviceId)
    }
}


extension Publishers.Create.Subscriber: @unchecked Sendable { }
