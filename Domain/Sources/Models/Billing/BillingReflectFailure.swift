//
//  BillingReflectFailure.swift
//  Domain
//
//  Created by sudo.park on 8/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// 결제가 끝난 뒤 서버 반영 단계에서만 이 타입으로 나간다 — 호출측이 "결제는 됐다"를 문구로 단정할 수 있게
public struct BillingReflectFailure: Error, @unchecked Sendable {

    public let underlying: any Error

    public init(_ underlying: any Error) {
        self.underlying = underlying
    }
}
