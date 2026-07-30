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


// MARK: - purchase

extension BillingRepositoryImple {

    public func postPurchase(signedTransaction: String) async throws -> BillingUserPlan {
        let body: [String: Any] = ["signed_transaction": signedTransaction]
        let json = try await self.requestJson(.post, BillingAPIEndpoints.purchases, parameters: body)
        return BillingUserPlanMapper(
            json: json, topupRemaining: json["topup_remaining"] as? Int
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
