//
//  BillingRepository.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol BillingRepository: AnyObject, Sendable {

    func loadPlans() async throws -> [BillingPlan]
    func loadTopups() async throws -> [BillingTopup]

    // 유저의 현재 발효 플랜 단독 조회. usage 응답에 얹혀 오는 경로와 독립 (#739)
    func loadUserPlan() async throws -> BillingUserPlan

    // 구매 반영 후 발효 플랜을 돌려준다 — 별도 usage 재조회가 필요 없다
    func postPurchase(signedTransaction: String) async throws -> BillingUserPlan

    func postTransactionUpdate(signedTransaction: String) async throws -> BillingUserPlan
}
