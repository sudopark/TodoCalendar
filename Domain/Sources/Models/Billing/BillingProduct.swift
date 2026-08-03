//
//  BillingProduct.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// StoreKit 상품 정보의 Domain 표현. displayPrice 는 스토어가 통화·지역가격을 반영한 문자열이라
// 서버 카탈로그가 아니라 이쪽이 가격의 유일한 출처다
public struct BillingProduct: Sendable, Equatable {

    public let productId: String
    public let displayName: String
    public let displayPrice: String

    public init(productId: String, displayName: String, displayPrice: String) {
        self.productId = productId
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}
