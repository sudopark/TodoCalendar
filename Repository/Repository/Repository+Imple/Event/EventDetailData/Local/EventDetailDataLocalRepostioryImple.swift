//
//  EventDetailDataLocalRepostioryImple.swift
//  Repository
//
//  Created by sudo.park on 10/28/23.
//

import Foundation
import Combine
import Domain
import AsyncFlatMap


public final class EventDetailDataLocalRepostioryImple: EventDetailDataRepository, Sendable {
    
    private let localStorage: EventDetailDataLocalStorage
    public init(localStorage: EventDetailDataLocalStorage) {
        self.localStorage = localStorage
    }
}

extension EventDetailDataLocalRepostioryImple {
    
    public func loadDetail(_ id: String) -> AnyPublisher<EventDetailData, Never> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadDetail(id) ?? .init(id)
        }
        .eraseToAnyPublisher()
    }
    
    public func saveDetail(_ detail: EventDetailData) async throws -> EventDetailData {
        try await self.localStorage.saveDetail(detail)
        return detail
    }
    
    public func removeDetail(_ id: String) async throws {
        try await self.localStorage.removeDetail(id)
    }
}
