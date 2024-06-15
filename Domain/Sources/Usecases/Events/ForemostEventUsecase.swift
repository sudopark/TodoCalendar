//
//  ForemostEventUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


public protocol ForemostEventUsecase: Sendable {
    
    func refresh()
    func update(foremost eventId: ForemostEventId) async throws
    func remove() async throws
    
    var foremostEventId: AnyPublisher<ForemostEventId?, Never> { get }
}

public final class ForemostEventUsecaseImple: ForemostEventUsecase, @unchecked Sendable {
    
    private let repository: any ForemostEventRepository
    private let sharedDataStore: SharedDataStore
    init(
        repository: any ForemostEventRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.repository = repository
        self.sharedDataStore = sharedDataStore
    }
    
    private var cancellables: Set<AnyCancellable> = []
}

extension ForemostEventUsecaseImple {
    
    public func refresh() {
        
        self.repository.foremostEvent()
            .map { event in event.map { ForemostEventId(event: $0) } }
            .sink(receiveValue: self.updateForemost())
            .store(in: &self.cancellables)
    }
    
    public func update(foremost eventId: ForemostEventId) async throws {
        let eventId = try await self.repository.updateForemostEvent(eventId)
        self.updateForemost()(eventId)
    }
    
    public func remove() async throws {
        try await self.repository.removeForemostEvent()
        self.updateForemost()(nil)
    }
    
    private func updateForemost() -> (ForemostEventId?) -> Void {
        return { [weak self] eventId in
            let dataKey = ShareDataKeys.foremostEventId.rawValue
            if let eventId {
                self?.sharedDataStore.put(ForemostEventId.self, key: dataKey, eventId)
            } else {
                self?.sharedDataStore.delete(dataKey)
            }
        }
    }
}

extension ForemostEventUsecaseImple {
    
    public var foremostEventId: AnyPublisher<ForemostEventId?, Never> {
        return self.sharedDataStore
            .observe(ForemostEventId.self, key: ShareDataKeys.foremostEventId.rawValue)
    }
}
