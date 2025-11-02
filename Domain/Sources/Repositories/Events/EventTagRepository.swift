//
//  EventTagRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Combine

public protocol EventTagRepository: Sendable {
    
    func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag
    func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag
    func deleteTag(_ tagId: String) async throws
    func deleteTagWithAllEvents(_ tagId: String) async throws -> RemoveCustomEventTagWithEventsResult
    
    func loadAllCustomTags() -> AnyPublisher<[CustomEventTag], any Error>
    func loadCustomTags(_ ids: [String]) -> AnyPublisher<[CustomEventTag], any Error>
    
    func loadOffTags() -> Set<EventTagId>
    func toggleTagIsOn(_ tagId: EventTagId) -> Set<EventTagId>
    func addOffIds(_ ids: [EventTagId]) -> Set<EventTagId>
    func resetExternalCalendarOffTagId(_ serviceId: String)
}
