//
//  EventTagLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
import Combine
import AsyncFlatMap
import Domain
import Extensions


public final class EventTagLocalRepositoryImple: EventTagRepository {
    
    private let localStorage: EventTagLocalStorage
    public init(localStorage: EventTagLocalStorage) {
        self.localStorage = localStorage
    }
}


extension EventTagLocalRepositoryImple {
    
    public func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag {
        let sameNameTags = try await self.localStorage.loadTag(match: params.name)
        guard sameNameTags.isEmpty
        else {
            throw RuntimeError(key: "EvnetTag_Name_Duplicated", "event tag name:\(params.name) is already exists")
        }
        let tag = EventTag(uuid: UUID().uuidString, name: params.name, colorHex: params.colorHex, createAt: Date().timeIntervalSince1970)
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
    
    public func loadTags(
        olderThan time: TimeInterval?,
        size: Int
    ) async throws -> [EventTag] {
        
        return try await self.localStorage.loadTags(olderThan: time, size: size)
    }
}
