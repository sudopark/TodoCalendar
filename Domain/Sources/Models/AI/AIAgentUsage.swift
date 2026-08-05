//
//  AIAgentUsage.swift
//  Domain
//
//  Created by sudo.park on 5/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct AIAgentUsage: Sendable {

    public var date: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let dailyLimit: Int
    // 서버가 credit 단위로 집계한 사용량. 미배포 응답엔 없어 옵셔널
    public var creditsUsed: Int?
    // 일일 한도 리셋 시각 (UTC 자정)
    public var resetsAt: Date?
    public var updatedAt: Date?

    public init(
        input: Int, output: Int, limit: Int
    ) {
        self.inputTokens = input
        self.outputTokens = output
        self.dailyLimit = limit
    }

}


// MARK: - 사용량 파생

public extension AIAgentUsage {

    // 서버가 credit 집계를 안 내려주는 구간(미배포)에선 토큰 합으로 폴백
    var usedCredits: Int { self.creditsUsed ?? (self.inputTokens + self.outputTokens) }

    // 한도 소진 여부 — usedRatio 는 1.0 클램프라 초과를 구분 못 해 별도 파생 (#763)
    var isLimitExceeded: Bool {
        return self.dailyLimit > 0 && self.usedCredits >= self.dailyLimit
    }

    // 사용률 0~1 클램프 — 한도 미설정(0)은 0으로 취급
    var usedRatio: Double {
        guard self.dailyLimit > 0 else { return 0 }
        return min(Double(self.usedCredits) / Double(self.dailyLimit), 1.0)
    }
}


// MARK: - AIAgentUsageLoadResult

// GET /v1/ai/usage 응답 하나가 usage 와 plan 두 정보를 함께 내려주지만,
// 플랜 정보의 정본은 billingUserPlan 키 하나 — usage 에 흡수시키지 않고 나란히 반환한다 (#739)
public struct AIAgentUsageLoadResult: Sendable {

    public let usage: AIAgentUsage
    public let userPlan: BillingUserPlan?

    public init(usage: AIAgentUsage, userPlan: BillingUserPlan?) {
        self.usage = usage
        self.userPlan = userPlan
    }
}
