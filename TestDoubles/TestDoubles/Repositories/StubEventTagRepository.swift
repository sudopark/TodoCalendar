//
//  StubEventTagRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/09/24.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions


open class StubEventTagRepository: EventTagRepository, @unchecked Sendable {
    
    public init() { } 
    
    public var makeFailError: (any Error)?
    open func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag {
        if let error = self.makeFailError {
            throw error
        }
        return .init(name: params.name, colorHex: params.colorHex)
    }
    
    public var updateFailError: (any Error)?
    open func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag {
        if let error = updateFailError {
            throw error
        }
        return .init(uuid: tagId, name: params.name, colorHex: params.colorHex)
    }
    
    public var shouldFailLoadTagsInRange: Bool = false
    public var tagsMocking: ([String]) -> [EventTag] = { ids in
        return ids.map {
            return .init(uuid: $0, name: "name:\($0)", colorHex: "color")
        }
    }
    open func loadTags(_ ids: [String]) -> AnyPublisher<[EventTag], any Error> {
        guard self.shouldFailLoadTagsInRange == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        return Just(self.tagsMocking(ids)).mapNever().eraseToAnyPublisher()
    }
    
    public var allTagsStubbing: [EventTag] = []
    public func loadAllTags() -> AnyPublisher<[EventTag], any Error> {
        return Just(allTagsStubbing)
            .mapNever()
            .eraseToAnyPublisher()
    }
    
    private var offTagIdSet: Set<String> = []
    public func loadOffTags() -> Set<String> {
        return offTagIdSet
    }
    
    public func toggleTagIsOn(_ tagId: String) -> Set<String> {
        let newSet = self.offTagIdSet |> elem(tagId) .~ !offTagIdSet.contains(tagId)
        self.offTagIdSet = newSet
        return newSet
    }
}
