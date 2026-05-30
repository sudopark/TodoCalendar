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
