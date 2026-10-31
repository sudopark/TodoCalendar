//
//  EventSyncTimestampTable.swift
//  EventDomain
//
//  Created by sudo.park on 7/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import EventDomainInterface


public typealias EventSyncTimestampTable = EventSyncTimestampTableV0

@Table("SyncTimestamp")
public struct EventSyncTimestampTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "data_type")
    public let dataType: String
    
    @Column(.notNull)
    public let timestamp: Int
}


extension EventSyncTimestampTable.Entity {

    public init(_ timestamp: EventSyncTimestamp) {
        self.init(
            dataType: timestamp.dataType.rawValue,
            timestamp: timestamp.timeStampInt
        )
    }

    func asSyncTimestamp() throws -> EventSyncTimestamp {
        return try EventSyncTimestamp(
            try SyncDataType(rawValue: self.dataType).unwrap(),
            self.timestamp
        )
    }
}
