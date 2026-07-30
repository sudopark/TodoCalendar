//
//  BillingTransactionOutcome.swift
//  Domain
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// AppStoreBillingService 서비스 경계 결과 — 유저 취소와 승인대기(Ask to Buy)는
// 둘 다 "성공한 트랜잭션이 없다"는 점은 같지만 UI 대응이 다르다(취소는 닫기, 승인대기는 안내)
public enum BillingTransactionOutcome: Sendable {
    case verified(BillingSignedTransaction)
    case cancelled
    // 승인대기(Ask to Buy) — 나중에 transactionUpdates 로 도착한다
    case pending
}
