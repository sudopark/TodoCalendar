//
//  BillingRestoreResult.swift
//  Domain
//
//  Created by sudo.park on 8/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// BillingUsecase.restorePurchases 경계 결과 — .synced 의 트랜잭션이 서버 반영 후 플랜으로 치환된다
public enum BillingRestoreResult: Sendable {
    case applied(BillingUserPlan)
    case nothingToRestore
    case cancelled
}
