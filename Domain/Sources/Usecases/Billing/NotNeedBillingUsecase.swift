//
//  NotNeedBillingUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// 결제는 로그인 유저 전용 — 미로그인 세션과 paywall 플래그 off 세션엔 composition root 가
// 이걸 주입한다. 소비자는 로그인 여부를 모른 채 그대로 호출하고 여기서 전부 무동작으로 끝난다.
public final class NotNeedBillingUsecase: BillingUsecase, Sendable {

    private let sharedDataStore: SharedDataStore

    // 로그아웃은 clearAll 로 키를 지운 뒤 팩토리를 재생성하므로, init 에서 seed 하면 항상 그 clear 다음에 들어간다
    public init(sharedDataStore: SharedDataStore) {
        self.sharedDataStore = sharedDataStore
        let freePlan = BillingUserPlan() |> \.planId .~ .free
        sharedDataStore.put(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue, freePlan)
    }

    public func loadPlanOfferings() async throws -> [BillingPlanOffering] { return [] }
    public func loadTopupOfferings() async throws -> [BillingTopupOffering] { return [] }

    // 진입점이 로그인 가드로 막혀 있어 도달하지 않는다. 도달하면 가드가 뚫린 것이라 드러낸다
    public func purchase(productId: String) async throws -> BillingPurchaseResult {
        throw RuntimeError(key: "Billing.needSignIn", "billing needs sign in")
    }

    public func restorePurchases() async throws -> BillingRestoreResult { return .nothingToRestore }

    @discardableResult
    public func refreshUserPlan() async throws -> BillingUserPlan {
        throw RuntimeError(key: "Billing.needSignIn", "billing needs sign in")
    }

    public func startObservingTransactions() { }
    public func stopObservingTransactions() { }
    public func recoverUnfinishedTransactions() { }
    public func hasUnfinishedTransactions() async -> Bool { return false }
    public func applyUnfinishedTransactions() async throws -> BillingUserPlan? { return nil }

    // 플랜 정보는 결제 기능이 아니다 — AI usage 응답도 같은 키를 채우므로
    // paywall 이 닫혀도 사용량 게이지는 플랜을 읽어야 한다
    public var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
        return self.sharedDataStore.observe(
            BillingUserPlan.self,
            key: ShareDataKeys.billingUserPlan.rawValue
        )
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
