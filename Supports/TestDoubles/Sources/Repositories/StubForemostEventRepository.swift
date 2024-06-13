//
//  StubForemostEventRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 6/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit


open class StubForemostEventRepository: ForemostEventRepository, BaseStub, @unchecked Sendable {
    
    public init() { }
    
    public var shouldLoadfailEvent: Bool = false
    public var stubForemostEvent: (any ForemostMarkableEvent)?
    open func foremostEvent() -> AnyPublisher<(any ForemostMarkableEvent)?, any Error> {
        guard self.shouldLoadfailEvent == false
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        
        return Just(self.stubForemostEvent).mapNever().eraseToAnyPublisher()
    }
    
    public var shouldFailUpdate: Bool = false
    open func updateForemostEvent(_ eventId: String) async throws -> ForemostEventId {
        try self.checkShouldFail(self.shouldFailUpdate)
        self.stubForemostEvent = TodoEvent(uuid: eventId, name: "new")
        return .init(eventId, true)
    }
    
    public var shouldFailRemove: Bool = false
    open func removeForemostEvent() async throws {
        try self.checkShouldFail(self.shouldFailRemove)
        self.stubForemostEvent = nil
    }
}
