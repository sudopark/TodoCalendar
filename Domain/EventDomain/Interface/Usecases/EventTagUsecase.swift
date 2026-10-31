//
//  EventTagUsecase.swift
//  EventDomainInterface
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - EventTagUsecase

public protocol EventTagUsecase: AnyObject, Sendable {
    
    func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag
    func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag
    func deleteTag(_ tagId: String) async throws
    func deleteTagWithAllEvents(_ tagId: String) async throws
    
    func prepare()
    func refreshCustomTags(_ ids: [String])
    func eventTag(id: EventTagId) -> AnyPublisher<(any EventTag)?, Never>
    func eventTags(_ ids: [EventTagId]) -> AnyPublisher<[EventTagId: any EventTag], Never>
    func loadAllEventTags() -> AnyPublisher<[any EventTag], any Error>
    var sharedEventTags: AnyPublisher<[EventTagId: any EventTag], Never> { get }
    
    func toggleEventTagIsOnCalendar(_ tagId: EventTagId)
    func addEventTagOffIds(_ ids: [EventTagId])
    func removeEventTagOffIds(_ ids: [EventTagId])
    func offEventTagIdsOnCalendar() -> AnyPublisher<Set<EventTagId>, Never>
    func resetExternalCalendarOffTagId(_ serviceId: String)
}
