//
//  BillingPurchaseResult.swift
//  Domain
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// BillingUsecase.purchase 유즈케이스 경계 결과 — BillingTransactionOutcome.verified 가
// 서버 반영까지 끝난 뒤 최신 플랜으로 치환된다
public enum BillingPurchaseResult: Sendable {
    case applied(BillingUserPlan)
    case cancelled
    case pending
}
