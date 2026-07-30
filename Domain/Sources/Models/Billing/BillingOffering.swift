//
//  BillingOffering.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// 서버 카탈로그(무엇을 파는가) + StoreKit 상품(얼마인가)의 결합.
// product 가 nil 인 경우: free 처럼 상품이 없거나, 스토어 조회가 실패한 경우
public struct BillingPlanOffering: Sendable, Equatable {

    public let plan: BillingPlan
    public var product: BillingProduct?

    public init(plan: BillingPlan) {
        self.plan = plan
    }
}


public struct BillingTopupOffering: Sendable, Equatable {

    public let topup: BillingTopup
    public var product: BillingProduct?

    public init(topup: BillingTopup) {
        self.topup = topup
    }
}
