//
//  StubBillingRepository.swift
//  DomainTests
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Extensions

@testable import Domain


final class StubBillingRepository: BillingRepository, @unchecked Sendable {

    private let shouldFailPurchase: Bool
    private let failingJWSTokens: Set<String>
    private let shouldFailLoadUserPlan: Bool
    private let stubAppAccountToken: UUID?

    init(
        shouldFailPurchase: Bool = false,
        failingJWSTokens: Set<String> = [],
        shouldFailLoadUserPlan: Bool = false,
        appAccountToken: UUID? = UUID(uuidString: "8f14e45f-ceea-467a-9c8f-1b3a2e5d7c04")
    ) {
        self.shouldFailPurchase = shouldFailPurchase
        self.failingJWSTokens = failingJWSTokens
        self.shouldFailLoadUserPlan = shouldFailLoadUserPlan
        self.stubAppAccountToken = appAccountToken
    }

    // 기록만 한다 — 검증은 테스트 케이스 책임
    private(set) var didPostedSignedTransactions: [String] = []

    func loadPlans() async throws -> [BillingPlan] {
        return [
            BillingPlan(id: .free, dailyLimit: 6500),
            BillingPlan(id: .standard, dailyLimit: 20000)
                |> \.productId .~ "plan.standard.monthly"
                |> \.isTopupAllowed .~ true
        ]
    }

    func loadTopups() async throws -> [BillingTopup] {
        return [
            BillingTopup(productId: "topup.tier.1", credits: 100_000)
        ]
    }

    // 기록만 한다 — 검증은 테스트 케이스 책임
    private(set) var didLoadUserAccountTimes: Int = 0

    func loadUserAccount() async throws -> BillingUserAccount {
        self.didLoadUserAccountTimes += 1
        guard !self.shouldFailLoadUserPlan
        else { throw RuntimeError("load user plan failed") }
        let plan = BillingUserPlan()
            |> \.planId .~ .standard
            |> \.topupRemaining .~ 45600
        return BillingUserAccount(plan: plan)
            |> \.appAccountToken .~ self.stubAppAccountToken
    }

    func postPurchase(signedTransaction: String) async throws -> BillingUserPlan {
        self.didPostedSignedTransactions.append(signedTransaction)
        guard !self.shouldFailPurchase,
              !self.failingJWSTokens.contains(signedTransaction)
        else { throw RuntimeError("purchase apply failed") }
        return BillingUserPlan()
            |> \.planId .~ .standard
            |> \.topupRemaining .~ 12300
    }

    // 기록만 한다 — 검증은 테스트 케이스 책임
    private(set) var didPostedTransactionUpdates: [String] = []

    func postTransactionUpdate(signedTransaction: String) async throws -> BillingUserPlan {
        self.didPostedTransactionUpdates.append(signedTransaction)
        guard !self.shouldFailPurchase,
              !self.failingJWSTokens.contains(signedTransaction)
        else { throw RuntimeError("transaction update apply failed") }
        return BillingUserPlan()
            |> \.planId .~ .standard
            |> \.topupRemaining .~ 12300
    }
}
