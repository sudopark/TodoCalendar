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
    
    private let remote: any RemoteAPI
    private let cacheStorage: any EventTagLocalStorage
    private let environmentStorage: any EnvironmentStorage
    
    public init(
        remote: any RemoteAPI,
        cacheStorage: any EventTagLocalStorage,
        environmentStorage: any EnvironmentStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
        self.environmentStorage = environmentStorage
    }
}

extension EventTagRemoteRepositoryImple {
    
    public func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag {
        let endpoint = EventTagEndpoints.make
        let payload = params.asJson()
        let mapper: EventTagMapper = try await self.remote.request(
            .post,
            endpoint,
            parameters: payload
        )
        let tag = mapper.tag
        try? await self.cacheStorage.saveTag(tag)
        return tag
    }
    
    public func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag {
        let endpoint = EventTagEndpoints.tag(id: tagId)
        let payload = params.asJson()
        let mapper: EventTagMapper = try await self.remote.request(
            .put,
            endpoint,
            parameters: payload
        )
        let tag = mapper.tag
        try? await self.cacheStorage.updateTags([tag])
        return tag
    }
    
    public func deleteTag(_ tagId: String) async throws {
        let endpoint = EventTagEndpoints.tag(id: tagId)
        let _: RemoveEventTagResult = try await self.remote.request(
            .delete,
            endpoint
        )
        try? await self.cacheStorage.deleteTag(tagId)
        self.deleteOfftagId(tagId)
    }
    
    public func loadAllTags() -> AnyPublisher<[EventTag], any Error> {
        return self.loadTagsAndReplaceCache { [weak self] in
            return try await self?.cacheStorage.loadAllTags()
        } thenFromRemote: { [weak self] in
            return try await self?.loadAllEventsFromRemote()
        }
    }
    
    private func loadAllEventsFromRemote() async throws -> [EventTag] {
        let endpoint = EventTagEndpoints.allTags
        let mappers: [EventTagMapper] = try await self.remote.request(
            .get, endpoint
        )
        return mappers.map { $0.tag }
    }
    
    public func loadTags(_ ids: [String]) -> AnyPublisher<[EventTag], any Error> {
        return self.loadTagsAndReplaceCache { [weak self] in
            return try await self?.cacheStorage.loadTags(in: ids)
        } thenFromRemote: { [weak self] in
            return try await self?.loadTagsFromRemote(ids)
        }
    }
    
    private func loadTagsFromRemote(_ ids: [String]) async throws -> [EventTag] {
        let endpoint = EventTagEndpoints.tags
        let mappers: [EventTagMapper] = try await self.remote.request(
            .get,
            endpoint,
            parameters: ["ids": ids]
        )
        return mappers.map { $0.tag }
    }
    
    private func loadTagsAndReplaceCache(
        startWithCached cacheOperation: @Sendable @escaping () async throws -> [EventTag]?,
        thenFromRemote remoteOperation: @Sendable @escaping () async throws -> [EventTag]?
    ) -> AnyPublisher<[EventTag], any Error> {
        return AnyPublisher<[EventTag]?, any Error>.create { subscriber in
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
        _ cached: [EventTag]?,
        _ refreshed: [EventTag]?
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
            self.deleteOfftagId($0.uuid)
        }
    }
    
    private var offIds: String { "off_eventtagIds_on_calendar" }
    
    public func loadOffTags() -> Set<AllEventTagId> {
        let idStringValues: [String]? = self.environmentStorage.load(self.offIds)
        let ids = idStringValues?.map { AllEventTagId($0) }
        return (ids ?? []) |> Set.init
    }
    
    public func toggleTagIsOn(_ tagId: AllEventTagId) -> Set<AllEventTagId> {
        let oldOffIds = self.loadOffTags()
        let newIds = oldOffIds |> elem(tagId) .~ !oldOffIds.contains(tagId)
        let newIdStringValues = newIds.map { $0.stringValue }
        self.environmentStorage.update(self.offIds, newIdStringValues)
        return newIds
    }
    
    private func deleteOfftagId(_ tagId: String) {
        let oldOffIds = self.loadOffTags()
        let newIds = oldOffIds |> elem(.custom(tagId)) .~ false
        let newIdStringValues = newIds.map { $0.stringValue }
        self.environmentStorage.update(self.offIds, newIdStringValues)
    }
}


extension Publishers.Create.Subscriber: @unchecked Sendable { }
