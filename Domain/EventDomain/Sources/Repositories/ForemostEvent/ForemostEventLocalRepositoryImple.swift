//
//  ForemostEventLocalRepositoryImple.swift
//  EventDomain
//
//  Created by sudo.park on 6/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Extensions
import EventDomainInterface



public final class ForemostEventLocalRepositoryImple: ForemostEventRepository {
    
    private let localStorage: any ForemostLocalStorage
    public init(
        localStorage: any ForemostLocalStorage
    ) {
        self.localStorage = localStorage
    }
}


extension ForemostEventLocalRepositoryImple {
    
    public func foremostEvent() -> AnyPublisher<(any ForemostMarkableEvent)?, any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadForemostEvent()
        }
        .eraseToAnyPublisher()
    }
    
    public func updateForemostEvent(_ eventId: ForemostEventId) async throws -> any ForemostMarkableEvent {
        try await self.localStorage.updateForemostEventId(eventId)
        return try await self.localStorage.loadForemostEvent(eventId).unwrap()
    }
    
    public func removeForemostEvent() async throws {
        try await self.localStorage.removeForemostEvent()
    }
}
