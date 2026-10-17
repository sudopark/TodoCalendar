//
//  BillingUserPlanStore.swift
//  Domain
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// 기록이 이 한 자리를 지난다 — 쓰는 자리마다 영속을 따로 부르면 다음에 생기는 자리가 조용히 빠진다
public protocol BillingUserPlanStore: BillingUserPlanSource {

    func observePlan() -> AnyPublisher<BillingUserPlan?, Never>
    func updatePlan(_ plan: BillingUserPlan)
}


public final class BillingUserPlanStoreImple: BillingUserPlanStore, Sendable {

    private let sharedDataStore: SharedDataStore
    private let repository: any BillingUserPlanRepository

    public init(
        sharedDataStore: SharedDataStore,
        repository: any BillingUserPlanRepository
    ) {
        self.sharedDataStore = sharedDataStore
        self.repository = repository
    }

    private var planKey: String { ShareDataKeys.billingUserPlan.rawValue }
}


extension BillingUserPlanStoreImple {

    public func latestUserPlan() -> BillingUserPlan? {
        return self.sharedDataStore.value(BillingUserPlan.self, key: self.planKey)
    }

    public func observePlan() -> AnyPublisher<BillingUserPlan?, Never> {
        return self.sharedDataStore.observe(BillingUserPlan.self, key: self.planKey)
    }

    // 앱 프로세스의 정본은 메모리다 — 먼저 쓴 뒤 확장이 읽을 스냅샷을 남긴다
    public func updatePlan(_ plan: BillingUserPlan) {
        self.sharedDataStore.put(BillingUserPlan.self, key: self.planKey, plan)
        self.repository.updatePlan(plan)
    }
}
