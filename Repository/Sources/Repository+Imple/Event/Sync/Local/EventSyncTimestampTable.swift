//
//  EventSyncTimestampTable.swift
//  Repository
//
//  Created by sudo.park on 7/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import Domain


typealias EventSyncTimestampTable = EventSyncTimestampTableV0

@Table("SyncTimestamp")
struct EventSyncTimestampTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "data_type")
    let dataType: String
    
    @Column(.notNull)
    let timestamp: Int
}


extension EventSyncTimestampTable.Entity {

    init(_ timestamp: EventSyncTimestamp) {
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
