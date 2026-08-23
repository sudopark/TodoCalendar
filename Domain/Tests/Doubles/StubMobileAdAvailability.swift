//
//  StubMobileAdAvailability.swift
//  DomainTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

@testable import Domain


final class StubMobileAdAvailability: MobileAdAvailability, @unchecked Sendable {

    let isStartedSubject: CurrentValueSubject<Bool, Never>

    init(isStarted: Bool = false) {
        self.isStartedSubject = .init(isStarted)
    }

    var isStarted: AnyPublisher<Bool, Never> {
        return self.isStartedSubject.eraseToAnyPublisher()
    }

    var isStartedNow: Bool {
        return self.isStartedSubject.value
    }
}
