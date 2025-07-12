//
//  EventSyncRepository.swift
//  Domain
//
//  Created by sudo.park on 7/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public protocol EventSyncRepository: Sendable {
    
    func syncIfNeed<T: Sendable>(
        for dataType: SyncDataType
    ) async throws -> EventSyncResponse<T>
    
    func syncAll<T: Sendable>(
        for dataType: SyncDataType
    ) async throws -> EventSyncResponse<T>
}
