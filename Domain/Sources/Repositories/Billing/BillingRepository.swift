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

    // 앱 밖에서 발견한 트랜잭션(갱신·환불·가족공유·승인통과·미완료 잔여)을 서버에 위임한다.
    // 종류 판별과 처리 필요 여부는 전부 서버가 하고, 앱은 200 을 "확인됨" 으로만 읽는다
    func postTransactionUpdate(signedTransaction: String) async throws -> BillingUserPlan
}
