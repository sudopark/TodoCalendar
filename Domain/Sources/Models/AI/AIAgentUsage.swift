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
    // 서버가 내려준 플랜. 미배포 응답·미지 id 는 nil
    public var plan: BillingPlanId?
    // 하향 예약 — 다음 차수부터 적용될 플랜 변경
    public var scheduledPlanChange: BillingUserPlan.ScheduledChange?
    // top-up 잔량. daily_limit 과 합산되지 않는 별도 풀
    public var topupRemaining: Int?

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

    // 사용률 0~1 클램프 — 한도 미설정(0)은 0으로 취급
    var usedRatio: Double {
        guard self.dailyLimit > 0 else { return 0 }
        return min(Double(self.usedCredits) / Double(self.dailyLimit), 1.0)
    }
}
