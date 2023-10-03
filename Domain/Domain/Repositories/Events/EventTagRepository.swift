//
//  EventTagRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Combine

public protocol EventTagRepository: Sendable {
    
    func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag
    func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag
    func deleteTag(_ tagId: String) async throws
    
    func loadAllTags() -> AnyPublisher<[EventTag], any Error>
    func loadTags(_ ids: [String]) -> AnyPublisher<[EventTag], any Error>
    
    func loadOffTags() -> Set<AllEventTagId>
    func toggleTagIsOn(_ tagId: AllEventTagId) -> Set<AllEventTagId>
}
