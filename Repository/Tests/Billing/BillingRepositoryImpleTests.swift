//
//  BillingRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain

@testable import Repository


final class BillingRepositoryImpleTests {

    private func makeRepository() -> BillingRepositoryImple {
        let remote = StubRemoteAPI(responses: DummyResponse().responses)
        return BillingRepositoryImple(remote: remote)
    }
}


// MARK: - 플랜 카탈로그

extension BillingRepositoryImpleTests {

    @Test func repository_loadPlans() async throws {
        // given
        let repository = self.makeRepository()
        // when
        let plans = try await repository.loadPlans()
        // then
        // 픽스처는 4개다 — 앱이 모르는 enterprise 는 드롭되고 아는 플랜만 살아남는다
        #expect(plans.map { $0.id } == [.free, .standard, .lifetime])
        #expect(plans.map { $0.dailyLimit } == [6500, 20000, 30000])
        #expect(plans.map { $0.productId } == [nil, "plan.standard.monthly", "plan.lifetime"])
        #expect(plans.map { $0.isTopupAllowed } == [false, true, true])
    }
}


// MARK: - top-up 카탈로그

extension BillingRepositoryImpleTests {

    @Test func repository_loadTopups() async throws {
        // given
        let repository = self.makeRepository()
        // when
        let topups = try await repository.loadTopups()
        // then
        #expect(topups.map { $0.productId } == ["topup.tier.1", "topup.tier.2", "topup.tier.3"])
        #expect(topups.map { $0.credits } == [100_000, 550_000, 1_200_000])
        #expect(topups.map { $0.bonusRate } == [0, 0.1, 0.2])
    }
}


// MARK: - 유저 플랜 단독 조회

extension BillingRepositoryImpleTests {

    @Test func repository_loadUserPlan_returnsCurrentPlan() async throws {
        // given
        let repository = self.makeRepository()
        // when
        let plan = try await repository.loadUserPlan()
        // then
        #expect(plan.planId == .standard)
        #expect(plan.topupRemaining == 45600)
        #expect(plan.scheduledChange?.planId == .free)
    }
}


// MARK: - 구매 반영

extension BillingRepositoryImpleTests {

    @Test func repository_postPurchase_returnsAppliedPlan() async throws {
        // given
        let repository = self.makeRepository()
        // when
        let plan = try await repository.postPurchase(signedTransaction: "jws_token")
        // then
        #expect(plan.planId == .standard)
        #expect(plan.topupRemaining == 12300)
        #expect(plan.scheduledChange?.planId == .free)
    }
}


// MARK: - 트랜잭션 위임

extension BillingRepositoryImpleTests {

    // 앱 밖에서 발견한 트랜잭션은 구매 확정과 다른 경로로 올린다 —
    // 종류 판별은 서버가 하므로 앱은 JWS 만 싣는다
    @Test func repository_postTransactionUpdate_returnsAppliedPlan() async throws {
        // given
        let repository = self.makeRepository()
        // when
        let plan = try await repository.postTransactionUpdate(signedTransaction: "jws_token")
        // then
        #expect(plan.planId == .lifetime)
        #expect(plan.topupRemaining == 7700)
    }
}


private struct DummyResponse {

    private var plansResponse: String {
        return """
        { "plans": [
            { "id": "free", "daily_limit": 6500, "product_id": null, "topup_allowed": false },
            { "id": "standard", "daily_limit": 20000, "product_id": "plan.standard.monthly", "topup_allowed": true },
            { "id": "lifetime", "daily_limit": 30000, "product_id": "plan.lifetime", "topup_allowed": true },
            { "id": "enterprise", "daily_limit": 99999, "product_id": "plan.enterprise", "topup_allowed": true }
        ]}
        """
    }

    private var topupsResponse: String {
        return """
        { "topups": [
            { "product_id": "topup.tier.1", "credits": 100000, "bonus_rate": 0 },
            { "product_id": "topup.tier.2", "credits": 550000, "bonus_rate": 0.1 },
            { "product_id": "topup.tier.3", "credits": 1200000, "bonus_rate": 0.2 }
        ]}
        """
    }

    private var purchaseResponse: String {
        return """
        {
            "id": "standard",
            "scheduled_change": { "plan_id": "free", "effective_at": "2026-08-26T00:00:00.000Z" },
            "topup_remaining": 12300
        }
        """
    }

    // 구매 확정 응답과 값을 일부러 다르게 둔다 — 잘못해서 purchases 로 나가면 TC 가 잡는다
    private var transactionResponse: String {
        return """
        {
            "id": "lifetime",
            "topup_remaining": 7700
        }
        """
    }

    // GET /v1/ai/usage 의 plan 필드·POST /v1/billing/purchases 응답과 동일 스키마
    private var userPlanResponse: String {
        return """
        {
            "id": "standard",
            "scheduled_change": { "plan_id": "free", "effective_at": "2026-08-26T00:00:00.000Z" },
            "topup_remaining": 45600
        }
        """
    }

    var responses: [StubRemoteAPI.Response] {
        return [
            .init(method: .get, endpoint: BillingAPIEndpoints.plans,
                  resultJsonString: .success(self.plansResponse)),
            .init(method: .get, endpoint: BillingAPIEndpoints.topups,
                  resultJsonString: .success(self.topupsResponse)),
            .init(method: .post, endpoint: BillingAPIEndpoints.purchases,
                  resultJsonString: .success(self.purchaseResponse)),
            .init(method: .post, endpoint: BillingAPIEndpoints.transactions,
                  resultJsonString: .success(self.transactionResponse)),
            .init(method: .get, endpoint: BillingAPIEndpoints.userPlan,
                  resultJsonString: .success(self.userPlanResponse))
        ]
    }
}
