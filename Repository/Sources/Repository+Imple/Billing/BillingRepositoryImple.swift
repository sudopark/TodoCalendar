//
//  BillingRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


public final class BillingRepositoryImple: BillingRepository {

    private let remote: any RemoteAPI

    public init(remote: any RemoteAPI) {
        self.remote = remote
    }
}


// MARK: - catalog

extension BillingRepositoryImple {

    public func loadPlans() async throws -> [BillingPlan] {
        let json = try await self.requestJson(.get, BillingAPIEndpoints.plans)
        let plans = json["plans"] as? [[String: Any]] ?? []
        return plans.compactMap { BillingPlanMapper(json: $0).plan }
    }

    public func loadTopups() async throws -> [BillingTopup] {
        let json = try await self.requestJson(.get, BillingAPIEndpoints.topups)
        let topups = json["topups"] as? [[String: Any]] ?? []
        return topups.compactMap { BillingTopupMapper(json: $0).topup }
    }
}


// MARK: - user plan

extension BillingRepositoryImple {

    public func loadUserPlan() async throws -> BillingUserPlan {
        let json = try await self.requestJson(.get, BillingAPIEndpoints.userPlan)
        return BillingUserPlanMapper(
            json: json, topupRemaining: json["topup_remaining"] as? Int
        ).userPlan
    }
}


// MARK: - purchase

extension BillingRepositoryImple {

    public func postPurchase(signedTransaction: String) async throws -> BillingUserPlan {
        let body: [String: Any] = ["signed_transaction": signedTransaction]
        let json = try await self.requestJson(.post, BillingAPIEndpoints.purchases, parameters: body)
        return BillingUserPlanMapper(
            json: json, topupRemaining: json["topup_remaining"] as? Int
        ).userPlan
    }

    public func postTransactionUpdate(signedTransaction: String) async throws -> BillingUserPlan {
        let body: [String: Any] = ["signed_transaction": signedTransaction]
        let json = try await self.requestJson(.post, BillingAPIEndpoints.transactions, parameters: body)
        // 이 엔드포인트만 user_plan 으로 감싸 응답한다. 못 벗기면 빈 플랜으로 흘리지 않고 실패시킨다 —
        // 매퍼가 throw 하지 않아 조용히 통과하면 보유 플랜이 지워지고 finish 까지 진행된다
        guard let userPlan = json["user_plan"] as? [String: Any]
        else { throw RuntimeError("invalid billing transaction response") }
        return BillingUserPlanMapper(
            json: userPlan, topupRemaining: userPlan["topup_remaining"] as? Int
        ).userPlan
    }
}


// MARK: - helpers

private extension BillingRepositoryImple {

    func requestJson(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        parameters: [String: Any] = [:]
    ) async throws -> [String: Any] {
        let data = try await self.remote.request(method, endpoint, with: nil, parameters: parameters)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw RuntimeError("invalid billing API response")
        }
        return json
    }
}
