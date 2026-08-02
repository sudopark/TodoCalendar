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


// 상품 종류. 구독과 1회 결제는 고지 문구가 갈린다 — 비소모품에 "자동 갱신"을 쓰면 리젝이다
public enum BillingProductKind: Sendable, Equatable {
    case subscription(period: BillingSubscriptionPeriod?)
    case oneTime
}


public struct BillingProduct: Sendable, Equatable {

    public let productId: String
    public let displayName: String
    // 가격의 유일한 출처는 StoreKit 이다 — 서버가 준 문자열을 쓰면 통화·지역가격이 어긋난다
    public let displayPrice: String
    // 스토어가 알려준 실제 종류. 앱이 plan id 로 추정하지 않는다
    public var kind: BillingProductKind?

    public init(productId: String, displayName: String, displayPrice: String) {
        self.productId = productId
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}
