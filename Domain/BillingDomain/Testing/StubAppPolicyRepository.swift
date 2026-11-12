//
//  StubAppPolicyRepository.swift
//  BillingDomainTesting
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import BillingDomainInterface



public final class StubAppPolicyRepository: AppPolicyRepository, @unchecked Sendable {

    private let policy: AppPolicy?

    public init(policy: AppPolicy? = nil) {
        self.policy = policy
    }

    public func loadPolicy() -> AppPolicy? {
        return self.policy
    }

    public func refreshPolicy() async throws { }
}
