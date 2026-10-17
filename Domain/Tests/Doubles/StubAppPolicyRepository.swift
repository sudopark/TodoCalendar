//
//  StubAppPolicyRepository.swift
//  DomainTests
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import Domain


final class StubAppPolicyRepository: AppPolicyRepository, @unchecked Sendable {

    private let policy: AppPolicy?

    init(policy: AppPolicy? = nil) {
        self.policy = policy
    }

    func loadPolicy() -> AppPolicy? {
        return self.policy
    }

    func refreshPolicy() async throws { }
}
