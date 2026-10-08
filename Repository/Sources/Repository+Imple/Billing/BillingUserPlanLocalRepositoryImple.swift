//
//  BillingUserPlanLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService


public final class BillingUserPlanLocalRepositoryImple: BillingUserPlanRepository, Sendable {

    private let sqliteService: SQLiteService

    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
}


extension BillingUserPlanLocalRepositoryImple {

    private typealias KV = KeyValueTable

    public func fetchPlan() -> BillingUserPlan? {
        let key = KeyValueTableKeys.billingUserPlan.rawValue
        let stored = self.sqliteService.run { db in
            try db.loadOne(KV.self, query: KV.selectAll { $0.key == key })?.value
        }
        guard let text = try? stored.get(),
              let mapper = try? JSONDecoder().decode(
                  StoredBillingUserPlanMapper.self, from: Data(text.utf8)
              )
        else { return nil }
        return mapper.plan
    }

    public func updatePlan(_ plan: BillingUserPlan) {
        guard let data = try? JSONEncoder().encode(StoredBillingUserPlanMapper(plan: plan)),
              let text = String(data: data, encoding: .utf8)
        else { return }

        _ = self.sqliteService.run { db in
            try db.insertOne(
                KV.self,
                entity: KV.Entity(.billingUserPlan, value: text),
                shouldReplace: true
            )
        }
    }
}
