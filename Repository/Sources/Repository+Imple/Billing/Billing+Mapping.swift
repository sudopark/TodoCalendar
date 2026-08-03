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
        // 앱이 모르는 플랜 id 는 통째로 버린다 — dailyLimit 만 있고 이름을 못 그리면 쓸모가 없다
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

// GET /v1/ai/usage 의 plan 필드와 POST /v1/billing/purchases 응답이 동일 스키마라
// 양쪽이 이 매퍼를 공유한다. topupRemaining 만 담기는 위치가 달라 인자로 받는다
// 카탈로그와 달리 유저 플랜은 planId 를 몰라도 topupRemaining·scheduledChange 가 UI에 필요하다 —
// planId 만 nil 로 두고 나머지는 살린다 (카탈로그처럼 항목 전체를 버리지 않음)
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
