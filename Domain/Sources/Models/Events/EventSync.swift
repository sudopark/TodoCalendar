//
//  EventSync.swift
//  Domain
//
//  Created by sudo.park on 7/8/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - sync data type and sync timestamp

public enum SyncDataType: String, Sendable, Decodable {
    case eventTag = "EventTag"
    case todo = "Todo"
    case schedule = "Schedule"
    
}

public struct EventSyncTimestamp: Equatable, Sendable {
    
    public let dataType: SyncDataType
    public let timeStampInt: Int
    
    public init(_ dataType: SyncDataType, _ timeStampInt: Int) {
        self.dataType = dataType
        self.timeStampInt = timeStampInt
    }
}


// MARK: - sync response

public struct EventSyncResponse<T: Sendable>: Sendable {
    
    public enum CheckResult: String, Sendable, Decodable {
        case noNeedToSync
        case needToSync
        case migrationNeeds
    }
    
    public let result: CheckResult
    public var newSyncTime: EventSyncTimestamp?
    public var created: [T]?
    public var updated: [T]?
    public var deletedIds: [String]?
    
    public init(_ result: CheckResult) {
        self.result = result
    }
}
