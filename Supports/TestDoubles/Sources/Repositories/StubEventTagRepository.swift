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
    open func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        if let error = self.makeFailError {
            throw error
        }
        return .init(name: params.name, colorHex: params.colorHex)
    }
    
    public var updateFailError: (any Error)?
    open func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag {
        if let error = updateFailError {
            throw error
        }
        return .init(uuid: tagId, name: params.name, colorHex: params.colorHex)
    }
    
    public func deleteTag(_ tagId: String) async throws {
        
    }
    
    open func deleteTagWithAllEvents(_ tagId: String) async throws -> RemoveCustomEventTagWithEventsResult {
        return .init(todoIds: ["todo"], scheduleIds: ["schedule"])
    }
    
    public var shouldFailLoadTagsInRange: Bool = false
    public var tagsMocking: ([String]) -> [CustomEventTag] = { ids in
        return ids.map {
            return .init(uuid: $0, name: "name:\($0)", colorHex: "color")
        }
    }
    open func loadCustomTags(_ ids: [String]) -> AnyPublisher<[CustomEventTag], any Error> {
        guard self.shouldFailLoadTagsInRange == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        return Just(self.tagsMocking(ids)).mapNever().eraseToAnyPublisher()
    }
    
    public var allTagsStubbing: [CustomEventTag] = []
    public func loadAllCustomTags() -> AnyPublisher<[CustomEventTag], any Error> {
        return Just(allTagsStubbing)
            .mapNever()
            .eraseToAnyPublisher()
    }
    
    private var offTagIdSet: Set<EventTagId> = []
    public func loadOffTags() -> Set<EventTagId> {
        return offTagIdSet
    }
    
    public func toggleTagIsOn(_ tagId: EventTagId) -> Set<EventTagId> {
        let newSet = self.offTagIdSet |> elem(tagId) .~ !offTagIdSet.contains(tagId)
        self.offTagIdSet = newSet
        return newSet
    }
    
    public func addOffIds(_ ids: [EventTagId]) -> Set<EventTagId> {
        let newSet = self.offTagIdSet.union(ids)
        self.offTagIdSet = newSet
        return newSet
    }
    
    public func resetExternalCalendarOffTagId(_ serviceId: String) {
        let newSet = self.offTagIdSet.filter { $0.externalServiceId != serviceId }
        self.offTagIdSet = newSet
    }
    
    public var stubLatestUsecaseTag: CustomEventTag?
    open func loadLatestUsedTag() async throws -> CustomEventTag? {
        return self.stubLatestUsecaseTag
    }
}
