//
//  BillingProduct.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// 구독 갱신 주기 — 고지문·가격 옆 기간 표기에 쓴다
public enum BillingSubscriptionPeriod: Sendable, Equatable {
    case weekly
    case monthly
    case yearly
}


public enum BillingProductKind: Sendable, Equatable {
    case subscription(period: BillingSubscriptionPeriod?)
    case oneTime
}


public struct BillingProduct: Sendable, Equatable {

    public let productId: String
    public let displayName: String
    public let displayPrice: String
    public var kind: BillingProductKind?

    public init(productId: String, displayName: String, displayPrice: String) {
        self.productId = productId
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}
