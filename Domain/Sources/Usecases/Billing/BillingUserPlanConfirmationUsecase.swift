//
//  BillingUserPlanConfirmationUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol BillingUserPlanConfirmationUsecase: Sendable {

    var userPlanConfirmation: AnyPublisher<BillingUserPlanConfirmation, Never> { get }
}


public final class BillingUserPlanConfirmationUsecaseImple: BillingUserPlanConfirmationUsecase, Sendable {

    private let sharedDataStore: SharedDataStore

    public init(sharedDataStore: SharedDataStore) {
        self.sharedDataStore = sharedDataStore
    }

    // 미확정(nil)을 걸러내지 않는다 — 걸러내면 fail-closed 판정이 성립하지 않는다
    public var userPlanConfirmation: AnyPublisher<BillingUserPlanConfirmation, Never> {
        return self.sharedDataStore.observe(
            BillingUserPlan.self,
            key: ShareDataKeys.billingUserPlan.rawValue
        )
        .map { plan -> BillingUserPlanConfirmation in
            guard let plan else { return .unconfirmed }
            return .confirmed(plan)
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}
