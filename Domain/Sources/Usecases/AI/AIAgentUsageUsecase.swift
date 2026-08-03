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
        let usage = try await self.repository.loadUsage()
        self.sharedDataStore.put(
            AIAgentUsage.self,
            key: ShareDataKeys.aiAgentUsage.rawValue,
            usage
        )
        return usage
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
