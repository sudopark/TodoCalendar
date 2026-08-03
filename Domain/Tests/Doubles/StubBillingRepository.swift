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

    init(shouldFailPurchase: Bool = false, failingJWSTokens: Set<String> = []) {
        self.shouldFailPurchase = shouldFailPurchase
        self.failingJWSTokens = failingJWSTokens
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

    func postPurchase(signedTransaction: String) async throws -> BillingUserPlan {
        self.didPostedSignedTransactions.append(signedTransaction)
        guard !self.shouldFailPurchase,
              !self.failingJWSTokens.contains(signedTransaction)
        else { throw RuntimeError("purchase apply failed") }
        return BillingUserPlan()
            |> \.planId .~ .standard
            |> \.topupRemaining .~ 12300
    }
}
