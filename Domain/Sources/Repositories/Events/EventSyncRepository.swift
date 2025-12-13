//
//  EventSyncRepository.swift
//  Domain
//
//  Created by sudo.park on 7/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public protocol EventSyncRepository: Sendable {
    
    func clearSyncTimestamp() async throws
    func loadLatestSyncDataTimestamp() async throws -> TimeInterval?
    
    func checkIsNeedSync(
        for dataType: SyncDataType
    ) async throws -> EventSyncCheckRespose
    
    func startSync<T: Sendable>(
        for dataType: SyncDataType,
        startFrom timestamp: Int?,
        pageSize: Int
    ) async throws -> EventSyncResponse<T>
    
    func continueSync<T: Sendable>(
        for dataType: SyncDataType,
        cursor: String,
        pageSize: Int
    ) async throws -> EventSyncResponse<T>
}
