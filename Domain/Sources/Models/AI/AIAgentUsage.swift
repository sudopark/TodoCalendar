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

    var usedTokens: Int { self.inputTokens + self.outputTokens }

    // 사용률 0~1 클램프 — 한도 미설정(0)은 0으로 취급
    var usedRatio: Double {
        guard self.dailyLimit > 0 else { return 0 }
        return min(Double(self.usedTokens) / Double(self.dailyLimit), 1.0)
    }
}
