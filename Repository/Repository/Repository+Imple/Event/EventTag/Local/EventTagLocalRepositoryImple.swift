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
    
    public func deleteTag(_ tagId: String) async throws {
        try await self.localStorage.deleteTag(tagId)
        self.deleteOfftagId(tagId)
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


private extension AllEventTagId {
    
    var stringValue: String {
        switch self {
        case .holiday: return "holiday"
        case .default: return "default"
        case .custom(let id): return id
        }
    }
    
    init(_ stringValue: String) {
        switch stringValue {
        case "holiday": self = .holiday
        case "default": self = .default
        default: self = .custom(stringValue)
        }
    }
}
