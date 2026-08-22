//
//  BillingUserPlanConfirmation.swift
//  Domain
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// 확인 중과 확정된 free 를 한 값으로 뭉개면 fail-closed 판정이 성립하지 않는다
public enum BillingUserPlanConfirmation: Sendable, Equatable {
    case unconfirmed
    case confirmed(BillingUserPlan)
}


extension BillingUserPlanConfirmation {

    // planId 가 nil 이면 앱이 모르는 신규 플랜이라 유료로 간주해 false 를 낸다 (fail-closed)
    public func isFreeConfirmed() -> Bool {
        guard case let .confirmed(plan) = self else { return false }
        return plan.planId == .free
    }
}
