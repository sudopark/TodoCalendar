//
//  DoneTodoEventTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/21.
//

import Foundation
import SQLiteService
import Domain
import Extensions


struct DoneTodoEventTable: Table {
    
    enum Colums: String, TableColumn {
        case uuid
        case originEventId = "origin_event_id"
        case name
        case doneTime = "done_time"
        case eventTagId = "tag_id"
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .notNull])
            case .originEventId: return .text([.notNull])
            case .name: return .text([.notNull])
            case .doneTime: return .real([.notNull])
            case .eventTagId: return .text([])
            }
        }
    }
    
    typealias ColumnType = Colums
    typealias EntityType = DoneTodoEvent
    static var tableName: String { "DoneTodos" }
    
    static func scalar(_ entity: EntityType, for column: Colums) -> (any ScalarType)? {
        switch column {
        case .uuid: return entity.uuid
        case .originEventId: return entity.originEventId
        case .name: return entity.name
        case .doneTime: return entity.doneTime.timeIntervalSince1970
        case .eventTagId: return entity.eventTagId
        }
    }
}

extension DoneTodoEvent: RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            uuid: try cursor.next().unwrap(),
            name: try cursor.next().unwrap(),
            originEventId: try cursor.next().unwrap(),
            doneTime: Date(timeIntervalSince1970: try cursor.next().unwrap())
        )
        self.eventTagId = cursor.next()
    }
}
