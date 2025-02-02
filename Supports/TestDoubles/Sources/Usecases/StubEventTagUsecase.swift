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


open class StubEventTagUsecase: EventTagUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var shouldMakeFail: Bool = false
    open func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        guard self.shouldMakeFail == false
        else {
            throw RuntimeError("failed")
        }
        return .init(name: params.name, colorHex: params.colorHex)
    }
    public var shouldEditFail: Bool = false
    open func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag {
        guard self.shouldEditFail == false
        else {
            throw RuntimeError("failed")
        }
        return .init(uuid: tagId, name: params.name, colorHex: params.colorHex)
    }
    
    public var shouldDeleteFail: Bool = false
    open func deleteTag(_ tagId: String) async throws {
        guard self.shouldDeleteFail == false 
        else {
            throw RuntimeError("failed")
        }
    }
    
    open func deleteTagWithAllEvents(_ tagId: String) async throws {
        
    }
    
    open func prepare() { }
    
    open func refreshCustomTags(_ ids: [String]) { }
    open func eventTags(_ ids: [EventTagId]) -> AnyPublisher<[EventTagId : any EventTag], Never> {
        let tags = ids
            .map { CustomEventTag(uuid: $0.customTagId ?? "", name: "some", colorHex: "0x000000") }
            .asDictionary { $0.tagId }
        return Just(tags).eraseToAnyPublisher()
    }
    
    public func eventTag(id: EventTagId) -> AnyPublisher<any EventTag, Never> {
        let tag: any EventTag = switch id {
        case .default:
            DefaultEventTag.default("default")
        case .holiday:
            DefaultEventTag.holiday("holiday")
        case .custom(let customId):
            CustomEventTag(uuid: customId, name: "some", colorHex: "0x000000")
        }
        return Just(tag).eraseToAnyPublisher()
    }
    
    public var allTagsLoadResult: Result<[any EventTag], any Error> = .success([])
    public func loadAllEventTags() -> AnyPublisher<[any EventTag], any Error> {
        switch allTagsLoadResult {
        case .success(let success):
            let defaults: [DefaultEventTag] = [.default("default"), .holiday("holiday")]
            return Just(defaults + success).mapAsAnyError().eraseToAnyPublisher()
        case .failure(let failure):
            return Fail(error: failure).eraseToAnyPublisher()
        }
    }
    
    private let offIds = CurrentValueSubject<Set<EventTagId>, Never>([])
    public func offEventTagIdsOnCalendar() -> AnyPublisher<Set<EventTagId>, Never> {
        return offIds.eraseToAnyPublisher()
    }
    
    public func toggleEventTagIsOnCalendar(_ tagId: EventTagId) {
        let newSet = offIds.value |> elem(tagId) .~ !offIds.value.contains(tagId)
        self.offIds.send(newSet)
    }
    
    
    public var sharedEventTags: AnyPublisher<[EventTagId : any EventTag], Never> {
        return Just([:]).eraseToAnyPublisher()
    }
}
