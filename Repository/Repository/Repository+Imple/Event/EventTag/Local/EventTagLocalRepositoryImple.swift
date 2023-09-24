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
    
    private let localStorage: EventTagLocalStorage
    private let environmentStorage: any EnvironmentStorage
    public init(
        localStorage: EventTagLocalStorage,
        environmentStorage: any EnvironmentStorage
    ) {
        self.localStorage = localStorage
        self.environmentStorage = environmentStorage
    }
}


extension EventTagLocalRepositoryImple {
    
    public func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag {
        let sameNameTags = try await self.localStorage.loadTag(match: params.name)
        guard sameNameTags.isEmpty
        else {
            throw RuntimeError(key: "EvnetTag_Name_Duplicated", "event tag name:\(params.name) is already exists")
        }
        let tag = EventTag(uuid: UUID().uuidString, name: params.name, colorHex: params.colorHex)
        try await self.localStorage.saveTag(tag)
        return tag
    }
    
    public func editTag(
        _ tagId: String,
        _ params: EventTagEditParams
    ) async throws -> EventTag {
        let sameNameOtherTags = try await self.localStorage.loadTag(match: params.name).filter { $0.uuid != tagId }
        guard sameNameOtherTags.isEmpty
        else {
            throw RuntimeError(key: "EvnetTag_Name_Duplicated", "event tag name:\(params.name) is already exists")
        }
        try await self.localStorage.editTag(tagId, with: params)
        return try await self.localStorage.loadTags(in: [tagId]).first.unwrap()
    }
}

extension EventTagLocalRepositoryImple {
    
    public func loadTags(_ ids: [String]) -> AnyPublisher<[EventTag], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadTags(in: ids)
        }
        .eraseToAnyPublisher()
    }
    
    public func loadAllTags() -> AnyPublisher<[EventTag], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadAllTags()
        }
        .eraseToAnyPublisher()
    }
    
    private var offIds: String { "off_eventtagIds_on_calendar" }
    
    public func loadOffTags() -> Set<String> {
        let ids: [String]? = self.environmentStorage.load(self.offIds)
        return (ids ?? []) |> Set.init
    }
    
    public func toggleTagIsOn(_ tagId: String) -> Set<String> {
        let oldOffIds = self.loadOffTags()
        let newIds = oldOffIds |> elem(tagId) .~ !oldOffIds.contains(tagId)
        self.environmentStorage.update(self.offIds, newIds)
        return newIds
    }
}
