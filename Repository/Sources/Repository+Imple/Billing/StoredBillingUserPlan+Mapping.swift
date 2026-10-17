//
//  StoredBillingUserPlan+Mapping.swift
//  Repository
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


struct StoredBillingUserPlanMapper: Codable {

    private enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case scheduledChange = "scheduled_change"
        case topupRemaining = "topup_remaining"
    }

    let plan: BillingUserPlan

    init(plan: BillingUserPlan) {
        self.plan = plan
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let planId = try container.decodeIfPresent(String.self, forKey: .planId)
            .flatMap { BillingPlanId(rawValue: $0) }
        let scheduledChange = try container
            .decodeIfPresent(ScheduledChangeEntry.self, forKey: .scheduledChange)?.change
        let topupRemaining = try container.decodeIfPresent(Int.self, forKey: .topupRemaining)

        self.plan = BillingUserPlan()
            |> \.planId .~ planId
            |> \.scheduledChange .~ scheduledChange
            |> \.topupRemaining .~ topupRemaining
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.plan.planId?.rawValue, forKey: .planId)
        try container.encodeIfPresent(self.plan.topupRemaining, forKey: .topupRemaining)
        try container.encodeIfPresent(
            self.plan.scheduledChange.map { ScheduledChangeEntry(change: $0) },
            forKey: .scheduledChange
        )
    }
}


// 예약 하나가 깨져도 봉투 전체를 잃지 않는다 — 봉투가 안 읽히면 유료 유저가 플랜 미수신으로 읽힌다
private struct ScheduledChangeEntry: Codable {

    private enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case effectiveAt = "effective_at"
    }

    let change: BillingUserPlan.ScheduledChange?

    init(change: BillingUserPlan.ScheduledChange) {
        self.change = change
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let planId = try container.decodeIfPresent(String.self, forKey: .planId)
            .flatMap { BillingPlanId(rawValue: $0) }
        let effectiveAt = try container.decodeIfPresent(Date.self, forKey: .effectiveAt)
        guard let planId, let effectiveAt
        else {
            self.change = nil
            return
        }
        self.change = .init(planId: planId, effectiveAt: effectiveAt)
    }

    func encode(to encoder: any Encoder) throws {
        guard let change = self.change else { return }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(change.planId.rawValue, forKey: .planId)
        try container.encode(change.effectiveAt, forKey: .effectiveAt)
    }
}
