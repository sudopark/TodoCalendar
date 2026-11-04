//
//  StubUserEventExistenceRepository.swift
//  DomainTests
//
//  Created by sudo.park on 10/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions

@testable import Domain


final class StubUserEventExistenceRepository: UserEventExistenceRepository, @unchecked Sendable {

    private let hasAnyEvent: Bool
    private let shouldFailFetch: Bool

    init(hasAnyEvent: Bool = false, shouldFailFetch: Bool = false) {
        self.hasAnyEvent = hasAnyEvent
        self.shouldFailFetch = shouldFailFetch
    }

    func fetchHasAnyEvent() async throws -> Bool {
        guard self.shouldFailFetch == false
        else {
            throw RuntimeError("failed")
        }
        return self.hasAnyEvent
    }
}
