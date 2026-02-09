//
//  EventTagRemote.swift
//  Repository
//
//  Created by sudo.park on 7/23/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions

public protocol EventTagRemote: Sendable {
    
    func makeTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag
    func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag
    func deleteTag(_ tagId: String) async throws
    func deleteTagWithAllEvents(_ tagId: String) async throws -> RemoveCustomEventTagWithEventsResult
    func deleteTagWithEvents(_ tagId: String, todos: [String], schedules: [String]) async throws
    func loadAllEventTags() async throws -> [CustomEventTag]
    func loadCustomTags(_ ids: [String]) async throws -> [CustomEventTag]
}


public final class EventTagRemoteImple: EventTagRemote {
    
    private let remote: any RemoteAPI
    public init(remote: any RemoteAPI) {
        self.remote = remote
    }
}


extension EventTagRemoteImple {
    
    public func makeTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        let endpoint = EventTagEndpoints.make
        let payload = params.asJson()
        let mapper: CustomEventTagMapper = try await self.remote.request(
            .post,
            endpoint,
            parameters: payload
        )
        return mapper.tag
    }
    
    public func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag {
        let endpoint = EventTagEndpoints.tag(id: tagId)
        let payload = params.asJson()
        let mapper: CustomEventTagMapper = try await self.remote.request(
            .put,
            endpoint,
            parameters: payload
        )
        return mapper.tag
    }
    
    public func deleteTag(_ tagId: String) async throws  {
        let endpoint = EventTagEndpoints.tag(id: tagId)
        let _: RemoveEventTagResult = try await self.remote.request(
            .delete,
            endpoint
        )
    }
    
    public func deleteTagWithAllEvents(_ tagId: String) async throws -> RemoveCustomEventTagWithEventsResult {
        let endpoint = EventTagEndpoints.tagAndEvents(id: tagId)
        let mapper: RemoveEventTagAndResultMapper = try await self.remote.request(
            .delete, endpoint
        )
        return mapper.result
    }
    
    public func deleteTagWithEvents(
        _ tagId: String,
        todos: [String],
        schedules: [String]
    ) async throws {
        let endpoint = EventTagEndpoints.tagWithEvents(id: tagId)
        let params: [String: Any] = [
            "todos": todos,
            "schedules": schedules
        ]
        let _: RemoveEventTagResult = try await self.remote.request(
            .delete, endpoint, parameters: params)
    }
    
    public func loadAllEventTags() async throws -> [CustomEventTag] {
        let endpoint = EventTagEndpoints.allTags
        let mappers: [CustomEventTagMapper] = try await self.remote.request(
            .get, endpoint
        )
        return mappers.map { $0.tag }
    }
    
    public func loadCustomTags(_ ids: [String]) async throws -> [CustomEventTag] {
        let endpoint = EventTagEndpoints.tags
        let mappers: [CustomEventTagMapper] = try await self.remote.request(
            .get,
            endpoint,
            parameters: ["ids": ids]
        )
        return mappers.map { $0.tag }
    }
}
