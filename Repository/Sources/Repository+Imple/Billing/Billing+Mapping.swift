//
//  Billing+Mapping.swift
//  Repository
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


// MARK: - response: BillingPlan

struct BillingPlanMapper {

    let plan: BillingPlan?

    init(json: [String: Any]) {
        guard let idRaw = json["id"] as? String,
              let id = BillingPlanId(rawValue: idRaw),
              let dailyLimit = json["daily_limit"] as? Int
        else {
            self.plan = nil
            return
        }
        self.plan = BillingPlan(id: id, dailyLimit: dailyLimit)
            |> \.productId .~ (json["product_id"] as? String)
            |> \.isTopupAllowed .~ ((json["topup_allowed"] as? Bool) ?? false)
    }
}


// MARK: - response: BillingTopup

struct BillingTopupMapper {

    let topup: BillingTopup?

    init(json: [String: Any]) {
        guard let productId = json["product_id"] as? String,
              let credits = json["credits"] as? Int
        else {
            self.topup = nil
            return
        }
        self.topup = BillingTopup(productId: productId, credits: credits)
            |> \.bonusRate .~ ((json["bonus_rate"] as? Double) ?? 0)
    }
}


// MARK: - response: BillingUserPlan

struct BillingUserPlanMapper {

    let userPlan: BillingUserPlan

    init(json: [String: Any], topupRemaining: Int?) {
        let scheduledChange = (json["scheduled_change"] as? [String: Any])
            .flatMap { BillingScheduledChangeMapper(json: $0).change }

        self.userPlan = BillingUserPlan()
            |> \.planId .~ (json["id"] as? String).flatMap { BillingPlanId(rawValue: $0) }
            |> \.scheduledChange .~ scheduledChange
            |> \.topupRemaining .~ topupRemaining
    }
}


struct BillingUserAccountMapper {

    let account: BillingUserAccount

    init(json: [String: Any]) {
        let plan = BillingUserPlanMapper(
            json: json, topupRemaining: json["topup_remaining"] as? Int
        ).userPlan

        self.account = BillingUserAccount(plan: plan)
            |> \.appAccountToken .~ (json["app_account_token"] as? String).flatMap { UUID(uuidString: $0) }
    }
}


struct BillingScheduledChangeMapper {

    let change: BillingUserPlan.ScheduledChange?

    init(json: [String: Any]) {
        let planId = (json["plan_id"] as? String)
            .flatMap { BillingPlanId(rawValue: $0) }
        let effectiveAt = RemoteDateParser.parse(json["effective_at"])
        guard let planId, let effectiveAt
        else {
            self.change = nil
            return
        }
        self.change = .init(planId: planId, effectiveAt: effectiveAt)
    }
}
