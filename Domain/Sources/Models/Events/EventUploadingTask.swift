//
//  EventUploadingTask.swift
//  Domain
//
//  Created by sudo.park on 7/22/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public struct EventUploadingTask: Sendable {
    
    public enum DataType: String, Sendable {
        case eventTag
        case todo
        case schedule
    }
    
    public var timestamp: TimeInterval
    public let dataType: DataType
    public let uuid: String
    public let isRemovingTask: Bool
    public var uploadFailCount: Int = 0
    
    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        dataType: DataType,
        uuid: String,
        isRemovingTask: Bool
    ) {
        self.timestamp = timestamp
        self.dataType = dataType
        self.uuid = uuid
        self.isRemovingTask = isRemovingTask
    }
}
