//
//  BillingSignedTransaction.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// 서명 검증을 통과한 App Store 트랜잭션. jws 가 서버 검증의 유일한 신뢰 원천이며
// 앱이 판단한 productId 는 참고값일 뿐이다 — 서버는 서명 payload 안의 값을 믿는다
public struct BillingSignedTransaction: Sendable, Equatable {

    public let id: String
    public let productId: String
    public let jws: String

    public init(id: String, productId: String, jws: String) {
        self.id = id
        self.productId = productId
        self.jws = jws
    }
}
