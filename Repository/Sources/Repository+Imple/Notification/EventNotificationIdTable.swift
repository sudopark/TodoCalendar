//
//  EventNotificationIdTable.swift
//  Repository
//
//  Created by sudo.park on 1/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService


struct EventNotificationIdTable: Table {
    
    enum Columns: String, TableColumn {
        case eventId = "event_id"
        case notificationReqId = "not_req_id"
        
        var dataType: ColumnDataType {
            switch self {
            case .eventId: return .text([.notNull])
            case .notificationReqId: return .text([.notNull])
            }
        }
    }
    
    struct Entity: RowValueType {
        let eventId: String
        let notificationReqId: String
        
        init(_ eventId: String, _ notificationReqId: String) {
            self.eventId = eventId
            self.notificationReqId = notificationReqId
        }
        
        init(_ cursor: CursorIterator) throws {
            self.init(
                try cursor.next().unwrap(),
                try cursor.next().unwrap()
            )
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = Entity
    static var tableName: String { "EventNotificationIds" }
    
    static func scalar(_ entity: Entity, for column: Columns) -> ScalarType? {
        switch column {
        case .eventId: return entity.eventId
        case .notificationReqId: return entity.notificationReqId
        }
    }
}
