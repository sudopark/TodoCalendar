//
//  EventSyncMediator.swift
//  EventDomainInterface
//
//  Created by sudo.park on 8/10/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions

public protocol EventSyncMediator: Sendable {
    
    func waitUntilEventSyncAvailable() async throws
}
