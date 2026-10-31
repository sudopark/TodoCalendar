//
//  AIAgentUsageUsecase.swift
//  AIDomainInterface
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions
import AsyncFlatMap

public protocol AIAgentUsageUsecase: AnyObject {

    func refresh()
    func loadUsage() async throws -> AIAgentUsage
    func isCreditExhausted() -> Bool

    var currentUsage: AnyPublisher<AIAgentUsage, Never> { get }
}
