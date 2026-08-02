//
//  AIAgentUsageUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import AsyncFlatMap


public protocol AIAgentUsageUsecase: AnyObject {
    
    func refresh()
    func loadUsage() async throws -> AIAgentUsage
    
    var currentUsage: AnyPublisher<AIAgentUsage, Never> { get }
}


public final class AIAgentUsageUsecaseImple: AIAgentUsageUsecase, @unchecked Sendable {
    
    private let repository: any AICommandRepository
    private let sharedDataStore: SharedDataStore
    
    public init(
        repository: any AICommandRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.repository = repository
        self.sharedDataStore = sharedDataStore
        
        self.internalBind()
    }
    
    private struct Subject {
        let refresh = PassthroughSubject<Void, Never>()
    }
    private let subject = Subject()
    private var cancellables = Set<AnyCancellable>()
}


extension AIAgentUsageUsecaseImple {
    
    public func refresh() {
        self.subject.refresh.send(())
    }
    
    private func internalBind() {
     
        let loadUsageWithoutError: () -> AnyPublisher<AIAgentUsage, Never> = { [weak self] in
            return Publishers.create(do: { [weak self] in
                try? await self?.loadUsage()
            })
            .eraseToAnyPublisher()
        }
        
        self.subject.refresh
            .map(loadUsageWithoutError)
            .switchToLatest()
            .sink(receiveValue: { _ in })
            .store(in: &self.cancellables)
    }
    
    public func loadUsage() async throws -> AIAgentUsage {
        let result = try await self.repository.loadUsage()
        self.sharedDataStore.put(
            AIAgentUsage.self,
            key: ShareDataKeys.aiAgentUsage.rawValue,
            result.usage
        )
        // nil 이면 put 하지 않는다 — 기존 값을 덮어 구매로 갱신된 최신 플랜을 지우면 안 된다 (#739)
        if let userPlan = result.userPlan {
            self.sharedDataStore.put(
                BillingUserPlan.self,
                key: ShareDataKeys.billingUserPlan.rawValue,
                userPlan
            )
        }
        return result.usage
    }
    
    public var currentUsage: AnyPublisher<AIAgentUsage, Never> {
        return self.sharedDataStore.observe(
            AIAgentUsage.self,
            key: ShareDataKeys.aiAgentUsage.rawValue
        )
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
