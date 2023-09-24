//
//  StubEventTagUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/08/10.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions


open class StubEventTagUsecase: EventTagUsecase {
    
    public init() { }
    
    open func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag {
        throw RuntimeError("failed")
    }
    open func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag {
        throw RuntimeError("failed")
    }
    
    open func bindRefreshRequireTagInfos() { }
    open func refreshTags(_ ids: [String]) { }
    open func eventTags(_ ids: [String]) -> AnyPublisher<[String: EventTag], Never> {
        let tags = ids
            .map { EventTag(uuid: $0, name: "some", colorHex: "0x000000") }
            .asDictionary { $0.uuid }
        return Just(tags).eraseToAnyPublisher()
    }
    
    public func eventTag(id: String) -> AnyPublisher<EventTag, Never> {
        let tag = EventTag(uuid: id, name: "some", colorHex: "0x000000")
        return Just(tag).eraseToAnyPublisher()
    }
    
    public var allTagsLoadResult: Result<[EventTag], any Error> = .success([])
    public func loadAllEventTags() -> AnyPublisher<[EventTag], any Error> {
        return allTagsLoadResult.eraseToAnyPublisher()
    }
    
    private let offIds = CurrentValueSubject<Set<String>, Never>([])
    public func offEventTagIdsOnCalendar() -> AnyPublisher<Set<String>, Never> {
        return offIds.eraseToAnyPublisher()
    }
    
    public func toggleEventTagIsOnCalendar(_ tagId: String) {
        let newSet = offIds.value |> elem(tagId) .~ !offIds.value.contains(tagId)
        self.offIds.send(newSet)
    }
}
