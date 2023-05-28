//
//  StubEventTagRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import Domain


class StubEventTagRepository: EventTagRepository, BaseStub, @unchecked Sendable {
    
    var makeFailError: Error?
    func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag {
        if let error = self.makeFailError {
            throw error
        }
        return EventTag(name: params.name, colorHex: params.colorHex)
    }
    
    var updateFailError: Error?
    func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag {
        if let error = updateFailError {
            throw error
        }
        return EventTag(uuid: tagId, name: params.name, colorHex: params.colorHex)
    }
    
    var shouldFailLoadTagsInRange: Bool = false
    var tagsMocking: ([String]) -> [EventTag] = { ids in
        return ids.map {
            return .init(uuid: $0, name: "name:\($0)", colorHex: "color")
        }
    }
    func loadTags(_ ids: [String]) -> AnyPublisher<[EventTag], Error> {
        guard self.shouldFailLoadTagsInRange == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        return Just(self.tagsMocking(ids)).mapNever().eraseToAnyPublisher()
    }
}
