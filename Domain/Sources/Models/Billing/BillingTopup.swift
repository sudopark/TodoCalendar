//
//  BillingTopup.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// GET /v1/billing/topups 의 한 항목
public struct BillingTopup: Sendable, Equatable {

    public let productId: String
    public let credits: Int
    public var bonusRate: Double = 0

    public init(productId: String, credits: Int) {
        self.productId = productId
        self.credits = credits
    }

    // 서버가 보너스를 반영해 적립하므로 표시용 총량도 같은 식으로 계산
    public var totalCredits: Int {
        return Int((Double(self.credits) * (1 + self.bonusRate)).rounded())
    }
}
