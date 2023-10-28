//
//  EventDetailDataRepository.swift
//  Domain
//
//  Created by sudo.park on 10/28/23.
//

import Foundation
import Combine


public protocol EventDetailDataRepository: Sendable {
    
    func loadDetail(_ id: String) -> AnyPublisher<EventDetailData, Never>
    func saveDetail(_ detail: EventDetailData) async throws -> EventDetailData
}

