//
//  BillingUsecase.swift
//  BillingDomainInterface
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions

public protocol BillingUsecase: AnyObject, Sendable {

    func loadPlanOfferings() async throws -> [BillingPlanOffering]
    func loadTopupOfferings() async throws -> [BillingTopupOffering]

    // 유저 취소·승인대기(Ask to Buy) 는 에러가 아니다 — 결과를 구분해 반환
    func purchase(productId: String) async throws -> BillingPurchaseResult
    func restorePurchases() async throws -> BillingRestoreResult

    // paywall 진입 등에서 현재 플랜을 재확인한다. 성공하면 sharedDataStore 에 반영돼
    // currentUserPlan 구독자에게 흐른다. 실패는 호출측이 처리 (throws)
    @discardableResult
    func refreshUserPlan() async throws -> BillingUserPlan

    func startObservingTransactions()

    func stopObservingTransactions()

    func recoverUnfinishedTransactions()

    func hasUnfinishedTransactions() async -> Bool

    func applyUnfinishedTransactions() async throws -> BillingUserPlan?

    // 구독을 걸 수 없는 순간에 즉시 판정해야 하는 호출부용 — currentUserPlan 과 같은 값을 본다
    func latestUserPlan() -> BillingUserPlan?

    var currentUserPlan: AnyPublisher<BillingUserPlan, Never> { get }
}
