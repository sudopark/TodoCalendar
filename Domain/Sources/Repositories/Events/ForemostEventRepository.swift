//
//  ForemostEventRepository.swift
//  Domain
//
//  Created by sudo.park on 6/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol ForemostEventRepository: Sendable {
    
    func foremostEvent() -> AnyPublisher<(any ForemostMarkableEvent)?, any Error>
    func updateForemostEvent(_ eventId: String) async throws -> ForemostEventId
    func removeForemostEvent() async throws
}
