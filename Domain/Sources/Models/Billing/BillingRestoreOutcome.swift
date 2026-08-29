//
//  BillingRestoreOutcome.swift
//  Domain
//
//  Created by sudo.park on 8/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// AppStoreBillingService 복원 경계 결과 — 시스템 로그인 시트 취소는 실패가 아니다
public enum BillingRestoreOutcome: Sendable {
    case synced([BillingSignedTransaction])
    case cancelled
}
