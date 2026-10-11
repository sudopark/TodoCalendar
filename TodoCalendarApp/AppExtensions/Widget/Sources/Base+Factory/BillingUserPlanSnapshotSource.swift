//
//  BillingUserPlanSnapshotSource.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


// 확장은 앱의 메모리 플랜 스토어를 못 읽어, 앱이 계정 DB 에 남긴 스냅샷을 플랜 원천으로 쓴다
struct BillingUserPlanSnapshotSource: BillingUserPlanSource {

    private let repository: any BillingUserPlanRepository

    init(repository: any BillingUserPlanRepository) {
        self.repository = repository
    }

    func latestUserPlan() -> BillingUserPlan? {
        return self.repository.fetchPlan()
    }
}
