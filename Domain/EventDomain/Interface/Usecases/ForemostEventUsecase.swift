//
//  ForemostEventUsecase.swift
//  EventDomainInterface
//
//  Created by sudo.park on 6/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions

public enum ForemostMarkingStatus: Sendable, Equatable {
    case idle
    case marking(evnetId: String)
    case unmarking
    
    public var markingEventId: String? {
        guard case .marking(let eventId) = self else { return nil }
        return eventId
    }
}

public protocol ForemostEventUsecase: Sendable {
    
    func refresh()
    func update(foremost eventId: ForemostEventId) async throws
    func remove() async throws
    
    var foremostEvent: AnyPublisher<(any ForemostMarkableEvent)?, Never> { get }
    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> { get }
}
