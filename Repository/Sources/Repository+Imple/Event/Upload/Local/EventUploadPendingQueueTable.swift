//
//  EventUploadPendingQueueTable.swift
//  Repository
//
//  Created by sudo.park on 7/21/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import SQLiteService
import Domain
import Extensions


struct EventUploadPendingQueueTable: Table {
    
    enum Colunms: String, TableColumn {
        case timestamp
        case dataType = "data_type"
        case uuid
        case isRemove = "is_remove"
        case uploadFailCount = "upload_fail_count"
        
        var dataType: ColumnDataType {
            switch self {
            case .timestamp: return .real([.notNull])
            case .dataType: return .text([.notNull])
            case .uuid: return .text([.unique, .notNull])
            case .isRemove: return .integer([.default(0), .notNull])
            case .uploadFailCount: return .integer([.default(0), .notNull])
            }
        }
    }
    
    typealias ColumnType = Colunms
    typealias EntityType = EventUploadingTask
    static var tableName: String { "event_upload_pending_queue" }
    
    static func scalar(_ entity: EntityType, for column: Colunms) -> (any ScalarType)? {
        switch column {
        case .timestamp: return entity.timestamp
        case .dataType: return entity.dataType.rawValue
        case .uuid: return entity.uuid
        case .isRemove: return entity.isRemovingTask
        case .uploadFailCount: return entity.uploadFailCount
        }
    }
}

extension EventUploadingTask: @retroactive RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        
        self.init(
            timestamp: try cursor.next().unwrap(),
            dataType: try EventUploadingTask.DataType(
                rawValue: try cursor.next().unwrap()).unwrap(),
            uuid: try cursor.next().unwrap(),
            isRemovingTask: try cursor.next().unwrap(),
        )
        self.uploadFailCount = try cursor.next().unwrap()
    }
}
