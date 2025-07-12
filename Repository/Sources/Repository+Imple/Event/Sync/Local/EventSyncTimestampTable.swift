//
//  EventSyncTimestampTable.swift
//  Repository
//
//  Created by sudo.park on 7/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain


struct EventSyncTimestampTable: Table {
    
    enum Columns: String, TableColumn {
        case dataType = "data_type"
        case timestamp = "timestamp"
        
        var dataType: ColumnDataType {
            switch self {
            case .dataType: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .timestamp: return .integer([.notNull])
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = EventSyncTimestamp
    static var tableName: String { "SyncTimestamp" }
    
    static func scalar(_ entity: EventSyncTimestamp, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .dataType: return entity.dataType.rawValue
        case .timestamp: return entity.timeStampInt
        }
    }
}


extension EventSyncTimestamp: @retroactive RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            try SyncDataType(rawValue: try cursor.next().unwrap()).unwrap(),
            try cursor.next().unwrap()
        )
    }
}
