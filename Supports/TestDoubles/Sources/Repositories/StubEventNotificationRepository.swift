//
//  StubEventNotificationRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 1/21/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubEventNotificationRepository: EventNotificationRepository, @unchecked Sendable {
    
    public init() { }
    
    
    open func removeAllSavedNotificationId(of eventIds: [String]) async throws -> [String] {
        return []
    }
    
    open func batchSaveNotificationId(_ eventIdNotificationIdMap: [String : [String]]) async throws {
        
    }
}

