//
//  BillingUserPlanStore.swift
//  BillingDomainInterface
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
